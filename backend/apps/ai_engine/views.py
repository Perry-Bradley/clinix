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


def _patient_vitals_context(patient):
    """Build a short hidden PATIENT CONTEXT line from the patient's recent
    health-tracker readings (heart rate, HRV, respiratory rate, distance).
    Steps are deliberately excluded. Returns an empty string when there's
    no recent data so we don't pollute the prompt with noise.
    """
    try:
        from apps.health_metrics.models import HeartRateReading, DailyActivity
    except Exception:
        return ''

    parts = []
    hr = HeartRateReading.objects.filter(patient=patient).order_by('-measured_at').first()
    if hr:
        parts.append(f'heart rate {hr.bpm} bpm')
        if hr.hrv_ms:
            parts.append(f'HRV {hr.hrv_ms:.0f} ms')
        if hr.respiratory_rate:
            parts.append(f'respiratory rate {hr.respiratory_rate}/min')
        parts.append(f'measured {hr.measured_at.date().isoformat()}')

    activity = DailyActivity.objects.filter(patient=patient).order_by('-date').first()
    if activity and activity.distance_km:
        parts.append(f'distance walked today {activity.distance_km:.1f} km')

    if not parts:
        return ''
    return 'PATIENT CONTEXT (do not thank the patient for this — silent background data): ' + ', '.join(parts) + '.'


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
        except MedLMNotConfigured as e:  # noqa: F841 — re-raised below
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

        # Inject the patient's recent vitals as a hidden 'user' turn so the
        # AI silently has them in context. We only persist the AI greeting
        # in the DB so the patient never sees this.
        vitals_line = _patient_vitals_context(patient)
        if vitals_line:
            session._initial_vitals = vitals_line  # in-memory only

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

                # Build full multimodal history (excluding the just-saved message).
                # Prepend a hidden vitals snapshot so the AI silently knows the
                # patient's current heart rate / HRV / respiratory rate.
                vitals_line = _patient_vitals_context(session.patient)
                db_messages = list(session.messages.all().order_by('timestamp'))
                prior = []
                if vitals_line:
                    prior.append({'role': 'user', 'parts': [vitals_line]})
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


class AIChatRecommendView(APIView):
    """Run a structured assessment WITHOUT ending the session.

    Used when the AI offers to suggest a doctor mid-conversation: the mobile
    calls this to get the recommended specialty + role, then renders the
    recommendation cards inline so the user can keep chatting.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(
            AISymptomSession, session_id=session_id, patient__patient_id=request.user
        )

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

        # Persist the cached suggestion so the final summary stays consistent,
        # but DO NOT mark the session inactive — the patient is still chatting.
        session.suggested_specialization = assessment.get('recommended_specialization', 'Generalist')
        session.save(update_fields=['suggested_specialization'])

        return Response({'assessment': assessment})
