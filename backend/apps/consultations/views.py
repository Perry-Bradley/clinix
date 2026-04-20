from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from .models import Consultation, Prescription, ChatMessage, MedicationReminder, MedicationLog
from apps.appointments.models import Appointment
from .serializers import (
    ConsultationSerializer, ConsultationStartSerializer,
    ConsultationEndSerializer, PrescriptionSerializer, WebRTCSignalSerializer,
    ChatMessageSerializer, MedicationReminderSerializer, MedicationLogSerializer
)
import uuid
import os
from django.conf import settings
from django.core.files.storage import default_storage

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

def _create_reminders_from_prescription(prescription):
    """Auto-generate MedicationReminder entries from a prescription's medications list."""
    from datetime import date, timedelta
    medications = prescription.medications or []
    for med in medications:
        name = med.get('name', '').strip()
        if not name:
            continue
        dosage = med.get('dosage', '')
        frequency = med.get('frequency', '').lower()
        duration_str = med.get('duration', '7 days')

        # Parse duration to days
        days = 7
        for part in duration_str.split():
            try:
                days = int(part)
                break
            except ValueError:
                continue

        # Parse frequency to reminder times
        times = ['08:00']
        if 'twice' in frequency or '2' in frequency or 'bid' in frequency:
            times = ['08:00', '20:00']
        elif 'three' in frequency or '3' in frequency or 'tid' in frequency:
            times = ['08:00', '14:00', '20:00']
        elif 'four' in frequency or '4' in frequency or 'qid' in frequency:
            times = ['08:00', '12:00', '16:00', '20:00']

        MedicationReminder.objects.create(
            prescription=prescription,
            patient=prescription.patient,
            medication_name=name,
            dosage=dosage,
            frequency=frequency or 'once daily',
            reminder_times=times,
            start_date=date.today(),
            end_date=date.today() + timedelta(days=days),
        )


class ConsultationPrescriptionView(generics.CreateAPIView):
    serializer_class = PrescriptionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        consultation_id = self.kwargs.get('pk')
        consultation = Consultation.objects.get(pk=consultation_id)
        prescription = serializer.save(
            consultation=consultation,
            patient=consultation.appointment.patient,
            provider=consultation.appointment.provider
        )
        # Auto-generate medication reminders
        _create_reminders_from_prescription(prescription)

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

import time
from agora_token_builder.RtcTokenBuilder import RtcTokenBuilder, Role_Publisher

class AgoraTokenView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        channel_name = request.query_params.get('channel', 'clinix_general')
        uid = 0
        expiration_time_in_seconds = 3600
        current_timestamp = int(time.time())
        privilege_expired_ts = current_timestamp + expiration_time_in_seconds

        app_id = os.environ.get("AGORA_APP_ID", "")
        app_certificate = os.environ.get("AGORA_APP_CERT", "")

        if not app_id or not app_certificate:
            return Response({'error': 'Agora API keys not configured on server'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        token = RtcTokenBuilder.buildTokenWithUid(
            app_id,
            app_certificate,
            channel_name,
            uid,
            Role_Publisher,
            privilege_expired_ts,
        )
        return Response({'app_id': app_id, 'token': token, 'channel': channel_name})


class ChatFileUploadView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            consultation = Consultation.objects.get(pk=pk)
            file_obj = request.FILES.get('file')
            if not file_obj:
                return Response({'error': 'No file provided'}, status=status.HTTP_400_BAD_REQUEST)
            
            message_type = request.data.get('message_type', 'file')
            caption = request.data.get('content', '')

            # Store file in media/chat_attachments/<consultation_id>/
            path = os.path.join('chat_attachments', str(pk), file_obj.name)
            filename = default_storage.save(path, file_obj)
            file_url = request.build_absolute_uri(settings.MEDIA_URL + filename)

            # Create the message object
            message = ChatMessage.objects.create(
                consultation=consultation,
                sender=request.user,
                message_type=message_type,
                content=caption,
                file_url=file_url,
                file_name=file_obj.name
            )

            return Response(ChatMessageSerializer(message).data, status=status.HTTP_201_CREATED)
        except Consultation.DoesNotExist:
            return Response({'error': 'Consultation not found'}, status=status.HTTP_404_NOT_FOUND)

class ChatMessageListView(generics.ListAPIView):
    serializer_class = ChatMessageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        consultation_id = self.kwargs.get('pk')
        return ChatMessage.objects.filter(consultation_id=consultation_id).order_by('created_at')


# ─── Medication Reminders ──────────────────────────────────────────────────

class PatientRemindersView(APIView):
    """Patient sees their active medication reminders."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from apps.patients.models import Patient
        try:
            patient = Patient.objects.get(patient_id=request.user)
        except Patient.DoesNotExist:
            return Response([], status=status.HTTP_200_OK)
        reminders = MedicationReminder.objects.filter(patient=patient, is_active=True)
        return Response(MedicationReminderSerializer(reminders, many=True).data)


class ReminderLogView(APIView):
    """Patient logs taken/skipped for a reminder at a specific time."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, reminder_id):
        logs = MedicationLog.objects.filter(reminder_id=reminder_id).order_by('-scheduled_time')[:30]
        return Response(MedicationLogSerializer(logs, many=True).data)

    def post(self, request, reminder_id):
        from apps.patients.models import Patient
        try:
            reminder = MedicationReminder.objects.get(id=reminder_id)
        except MedicationReminder.DoesNotExist:
            return Response({'error': 'Reminder not found'}, status=status.HTTP_404_NOT_FOUND)

        scheduled_time = request.data.get('scheduled_time')
        log_status = request.data.get('status', 'taken')
        if not scheduled_time:
            return Response({'error': 'scheduled_time required'}, status=status.HTTP_400_BAD_REQUEST)

        from datetime import datetime
        try:
            dt = datetime.fromisoformat(scheduled_time.replace('Z', '+00:00'))
        except (ValueError, AttributeError):
            return Response({'error': 'Invalid datetime format'}, status=status.HTTP_400_BAD_REQUEST)

        log, created = MedicationLog.objects.update_or_create(
            reminder=reminder,
            scheduled_time=dt,
            defaults={
                'patient': reminder.patient,
                'status': log_status,
                'responded_at': timezone.now(),
            },
        )
        return Response(MedicationLogSerializer(log).data)


class ReminderAdherenceView(APIView):
    """Get adherence stats for a patient's reminders."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from apps.patients.models import Patient
        try:
            patient = Patient.objects.get(patient_id=request.user)
        except Patient.DoesNotExist:
            return Response({'overall': 0, 'medications': []})

        reminders = MedicationReminder.objects.filter(patient=patient, is_active=True)
        medications = []
        total_taken = 0
        total_logs = 0
        for r in reminders:
            logs = r.logs.count()
            taken = r.logs.filter(status='taken').count()
            total_taken += taken
            total_logs += logs
            medications.append({
                'id': str(r.id),
                'name': r.medication_name,
                'dosage': r.dosage,
                'adherence': round((taken / logs) * 100) if logs > 0 else None,
                'total_doses': logs,
                'taken': taken,
            })
        overall = round((total_taken / total_logs) * 100) if total_logs > 0 else None
        return Response({'overall': overall, 'medications': medications})
