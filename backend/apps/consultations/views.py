from rest_framework import generics, permissions, status, serializers
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Q
from django.utils import timezone
from .models import Consultation, Prescription, ChatMessage, MedicationReminder, MedicationLog, MedicalRecord, Referral
from apps.appointments.models import Appointment
from apps.providers.models import HealthcareProvider
from apps.patients.models import Patient
from .serializers import (
    ConsultationSerializer, ConsultationStartSerializer,
    ConsultationEndSerializer, PrescriptionSerializer, WebRTCSignalSerializer,
    ChatMessageSerializer, MedicationReminderSerializer, MedicationLogSerializer,
    MedicalRecordSerializer, MedicalRecordShareSerializer, ReferralSerializer,
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


# ─── Medical Records ────────────────────────────────────────────────────────

def _provider_for_user(user):
    try:
        return HealthcareProvider.objects.get(provider_id=user)
    except HealthcareProvider.DoesNotExist:
        return None


def _patient_for_user(user):
    try:
        return Patient.objects.get(patient_id=user)
    except Patient.DoesNotExist:
        return None


class MedicalRecordListCreateView(generics.ListCreateAPIView):
    """List and create medical records.

    GET behaviour depends on the caller:
    * Patients see their own records.
    * Providers see records they authored, plus records explicitly shared with them.
    """
    serializer_class = MedicalRecordSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        provider = _provider_for_user(user)
        patient = _patient_for_user(user)

        qs = MedicalRecord.objects.all()
        if provider and patient:
            return qs.filter(
                Q(patient=patient) |
                Q(authored_by=provider) |
                Q(shared_with=provider)
            ).distinct()
        if provider:
            return qs.filter(
                Q(authored_by=provider) | Q(shared_with=provider)
            ).distinct()
        if patient:
            return qs.filter(patient=patient)
        return MedicalRecord.objects.none()

    def perform_create(self, serializer):
        # Only providers can author records
        provider = _provider_for_user(self.request.user)
        if not provider:
            raise serializers.ValidationError('Only providers can author medical records.')
        serializer.save(authored_by=provider)


class MedicalRecordDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = MedicalRecordSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'record_id'

    def get_queryset(self):
        user = self.request.user
        provider = _provider_for_user(user)
        patient = _patient_for_user(user)
        qs = MedicalRecord.objects.all()
        if provider and patient:
            return qs.filter(
                Q(patient=patient) |
                Q(authored_by=provider) |
                Q(shared_with=provider)
            ).distinct()
        if provider:
            return qs.filter(
                Q(authored_by=provider) | Q(shared_with=provider)
            ).distinct()
        if patient:
            return qs.filter(patient=patient)
        return MedicalRecord.objects.none()


class MedicalRecordShareView(APIView):
    """Patient grants or revokes another doctor's access to a medical record."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, record_id):
        patient = _patient_for_user(request.user)
        if not patient:
            return Response({'error': 'Only patients can share records.'}, status=status.HTTP_403_FORBIDDEN)
        try:
            record = MedicalRecord.objects.get(record_id=record_id, patient=patient)
        except MedicalRecord.DoesNotExist:
            return Response({'error': 'Record not found.'}, status=status.HTTP_404_NOT_FOUND)

        serializer = MedicalRecordShareSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            provider = HealthcareProvider.objects.get(provider_id=serializer.validated_data['provider_id'])
        except HealthcareProvider.DoesNotExist:
            return Response({'error': 'Provider not found.'}, status=status.HTTP_404_NOT_FOUND)

        if serializer.validated_data.get('revoke'):
            record.shared_with.remove(provider)
            return Response({'status': 'revoked', 'provider_id': str(provider.provider_id_id)})
        record.shared_with.add(provider)
        return Response({'status': 'granted', 'provider_id': str(provider.provider_id_id)})


# ─── Referrals ──────────────────────────────────────────────────────────────

class ReferralListCreateView(generics.ListCreateAPIView):
    """Doctor issues a referral; patient or destination doctor sees it."""
    serializer_class = ReferralSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        provider = _provider_for_user(user)
        patient = _patient_for_user(user)
        qs = Referral.objects.all()
        if provider and patient:
            return qs.filter(
                Q(patient=patient) |
                Q(referred_by=provider) |
                Q(referred_to=provider)
            ).distinct()
        if provider:
            return qs.filter(
                Q(referred_by=provider) | Q(referred_to=provider)
            ).distinct()
        if patient:
            return qs.filter(patient=patient)
        return Referral.objects.none()

    def perform_create(self, serializer):
        provider = _provider_for_user(self.request.user)
        if not provider:
            raise serializers.ValidationError('Only providers can issue referrals.')
        serializer.save(referred_by=provider)


class ReferralDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = ReferralSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'referral_id'
    queryset = Referral.objects.all()
