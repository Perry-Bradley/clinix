import base64
from django.db import transaction
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from .models import AISymptomSession, AIChatMessage
from apps.patients.models import Patient
from .serializers import (
    AISymptomSessionSerializer,
    AIChatMessageSerializer,
    SymptomChatMessageRequestSerializer,
)
from .medlm_client import medlm_client, MedLMNotConfigured, MedLMInferenceError


class AIChatStartView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        if request.user.user_type != 'patient':
            return Response({'error': 'Only patients can use the AI assistant'}, status=status.HTTP_403_FORBIDDEN)

        patient, _ = Patient.objects.get_or_create(
            patient_id=request.user,
            defaults={'gender': None, 'date_of_birth': None},
        )

        try:
            initial_greeting = medlm_client.get_opening_message()
        except MedLMNotConfigured as e:
            return Response(
                {'error': 'medlm_not_configured', 'detail': str(e)},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except MedLMInferenceError as e:
            return Response(
                {'error': 'medlm_inference_failed', 'detail': str(e)},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        session = AISymptomSession.objects.create(patient=patient)
        AIChatMessage.objects.create(session=session, sender='ai', message=initial_greeting)

        return Response(
            {'session_id': session.session_id, 'message': initial_greeting},
            status=status.HTTP_201_CREATED,
        )


class AIChatSessionListView(generics.ListAPIView):
    serializer_class = AISymptomSessionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return AISymptomSession.objects.filter(patient__patient_id=self.request.user).order_by('-created_at')


class AIChatMessageView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(AISymptomSession, session_id=session_id, patient__patient_id=request.user)

        if not session.is_active:
            return Response({'error': 'This session has ended'}, status=status.HTTP_400_BAD_REQUEST)

        serializer = SymptomChatMessageRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        user_message = serializer.validated_data['message']
        image_b64 = serializer.validated_data.get('image', None)

        # Decode the image if provided
        image_bytes = None
        mime_type = 'image/jpeg'
        if image_b64:
            try:
                # Strip data URI prefix if present (e.g. "data:image/png;base64,...")
                if ',' in image_b64:
                    header, image_b64 = image_b64.split(',', 1)
                    if 'png' in header:
                        mime_type = 'image/png'
                    elif 'webp' in header:
                        mime_type = 'image/webp'
                image_bytes = base64.b64decode(image_b64)
            except Exception:
                return Response({'error': 'Invalid image data.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            with transaction.atomic():
                # Save user message + optional image to DB
                AIChatMessage.objects.create(
                    session=session,
                    sender='user',
                    message=user_message,
                    image=image_b64 if image_b64 else None,
                )

                # Build full multimodal history (excluding the just-saved message)
                db_messages = list(session.messages.all().order_by('timestamp'))
                prior = []
                for msg in db_messages[:-1]:
                    parts = [msg.message]
                    if msg.image:
                        try:
                            img_data = msg.image
                            img_mime = 'image/jpeg'
                            if ',' in img_data:
                                hdr, img_data = img_data.split(',', 1)
                                if 'png' in hdr:
                                    img_mime = 'image/png'
                                elif 'webp' in hdr:
                                    img_mime = 'image/webp'
                            parts.append({
                                'data': base64.b64decode(img_data),
                                'mime_type': img_mime,
                            })
                        except Exception:
                            pass  # Skip corrupted image data silently
                    prior.append({
                        'role': 'user' if msg.sender == 'user' else 'model',
                        'parts': parts,
                    })

                ai_reply = medlm_client.get_chat_response(
                    prior, user_message,
                    image_data=image_bytes,
                    mime_type=mime_type,
                )
                AIChatMessage.objects.create(session=session, sender='ai', message=ai_reply)

        except MedLMNotConfigured as e:
            return Response(
                {'error': 'medlm_not_configured', 'detail': str(e)},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except MedLMInferenceError as e:
            return Response(
                {'error': 'medlm_inference_failed', 'detail': str(e)},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        return Response({'reply': ai_reply})


class AIChatDetailView(generics.RetrieveAPIView):
    serializer_class = AISymptomSessionSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'session_id'

    def get_queryset(self):
        return AISymptomSession.objects.filter(patient__patient_id=self.request.user)


class AIChatCompleteView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(AISymptomSession, session_id=session_id, patient__patient_id=request.user)

        history = []
        for msg in session.messages.all().order_by('timestamp'):
            history.append({
                'role': 'user' if msg.sender == 'user' else 'model',
                'parts': [msg.message],
            })

        try:
            assessment = medlm_client.get_structured_assessment(history)
        except MedLMNotConfigured as e:
            return Response(
                {'error': 'medlm_not_configured', 'detail': str(e)},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except MedLMInferenceError as e:
            return Response(
                {'error': 'medlm_inference_failed', 'detail': str(e)},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        session.ai_analysis = assessment
        session.recommendation = assessment.get('summary', '')
        session.suggested_specialization = assessment.get('recommended_specialization', 'Generalist')
        prio_map = {'Low': 1, 'Medium': 3, 'High': 5}
        session.triage_score = prio_map.get(str(assessment.get('triage_priority', 'Low')).strip(), 1)
        session.is_active = False
        session.save()

        return Response({'status': 'completed', 'assessment': assessment})
