from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from .models import Consultation, Prescription
from apps.appointments.models import Appointment
from .serializers import (
    ConsultationSerializer, ConsultationStartSerializer, 
    ConsultationEndSerializer, PrescriptionSerializer, WebRTCSignalSerializer
)
import uuid

class ConsultationStartView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = ConsultationStartSerializer(data=request.data)
        if serializer.is_valid():
            appointment_id = serializer.validated_data['appointment_id']
            try:
                appointment = Appointment.objects.get(appointment_id=appointment_id)
                # Check authorization (must be patient or provider of this apointment)
                user = request.user
                if getattr(appointment.patient, 'patient_id') != user and getattr(appointment.provider, 'provider_id') != user:
                    return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
                
                consultation, created = Consultation.objects.get_or_create(
                    appointment=appointment,
                    defaults={
                        'started_at': timezone.now(),
                        'webrtc_session_id': str(uuid.uuid4())
                    }
                )
                
                if not created and not consultation.started_at:
                    consultation.started_at = timezone.now()
                    consultation.save()
                    
                return Response(ConsultationSerializer(consultation).data)
            except Appointment.DoesNotExist:
                return Response({'error': 'Appointment not found'}, status=status.HTTP_404_NOT_FOUND)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class ConsultationDetailView(generics.RetrieveAPIView):
    serializer_class = ConsultationSerializer
    permission_classes = [permissions.IsAuthenticated]
    queryset = Consultation.objects.all()

class ConsultationEndView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, pk):
        try:
            consultation = Consultation.objects.get(pk=pk)
            # Only provider can end and save notes officially
            if getattr(consultation.appointment.provider, 'provider_id') == request.user:
                serializer = ConsultationEndSerializer(data=request.data)
                if serializer.is_valid():
                    consultation.ended_at = timezone.now()
                    consultation.provider_notes = serializer.validated_data.get('provider_notes', consultation.provider_notes)
                    consultation.diagnosis = serializer.validated_data.get('diagnosis', consultation.diagnosis)
                    consultation.save()
                    return Response(ConsultationSerializer(consultation).data)
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            else:
                return Response({'error': 'Unauthorized, only provider can save notes'}, status=status.HTTP_403_FORBIDDEN)
        except Consultation.DoesNotExist:
            return Response({'error': 'Consultation not found'}, status=status.HTTP_404_NOT_FOUND)

class ConsultationPrescriptionView(generics.CreateAPIView):
    serializer_class = PrescriptionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        consultation_id = self.kwargs.get('pk')
        consultation = Consultation.objects.get(pk=consultation_id)
        serializer.save(
            consultation=consultation,
            patient=consultation.appointment.patient,
            provider=consultation.appointment.provider
        )

class ConsultationTranscriptView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, pk):
        try:
            consultation = Consultation.objects.get(pk=pk)
            # Currently just returning the JSON field. Real scenario connects to ChatConsumer DB logic.
            return Response({'ai_transcript': consultation.ai_transcript or {}})
        except Consultation.DoesNotExist:
            return Response({'error': 'Consultation not found'}, status=status.HTTP_404_NOT_FOUND)

class WebRTCSignalEndpointView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        # We will handle WebRTC via Django Channels (WebSocket). 
        # This endpoint is kept for fallback or specific signal posting if needed.
        serializer = WebRTCSignalSerializer(data=request.data)
        if serializer.is_valid():
            return Response({'status': 'Signal relayed', 'data': serializer.validated_data['signal_data']})
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
