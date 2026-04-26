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


def _notify_patient_of_prescription(prescription):
    """Push + WS notification to the patient when a doctor issues a prescription,
    plus inject an inline chat message so the patient sees the prescription
    in their conversation with the doctor."""
    try:
        from apps.notifications.tasks import send_notification
        provider_name = (
            getattr(prescription.provider.provider_id, 'full_name', None)
            or 'Your doctor'
        )
        med_count = len(prescription.medications or [])
        body = (
            f"{provider_name} sent you a new prescription"
            + (f" with {med_count} medication{'s' if med_count != 1 else ''}." if med_count else '.')
        )
        send_notification.delay(
            prescription.patient.patient_id.user_id,
            'New prescription',
            body,
            'prescription',
            {'prescription_id': str(prescription.prescription_id)},
        )
    except Exception:
        pass

    # Drop a clinical chat message into the doctor↔patient conversation.
    try:
        from apps.direct_chat.clinical import post_clinical_message
        first_meds = [m.get('name', '') for m in (prescription.medications or [])][:2]
        summary = ', '.join([m for m in first_meds if m])
        post_clinical_message(
            doctor_user=prescription.provider.provider_id,
            patient_user=prescription.patient.patient_id,
            message_type='prescription',
            content=summary or 'New prescription',
            metadata={
                'prescription_id': str(prescription.prescription_id),
                'medication_count': len(prescription.medications or []),
                'instructions': (prescription.instructions or '')[:200],
            },
        )
    except Exception:
        pass


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
        _create_reminders_from_prescription(prescription)
        _notify_patient_of_prescription(prescription)


class DoctorPrescriptionCreateView(APIView):
    """Doctor writes a prescription for a patient they have an appointment with.

    Body: { appointment_id, medications: [{name, dosage, frequency, duration}], instructions? }
    The doctor must be the provider on a confirmed/completed appointment with the
    patient. We attach the prescription to that appointment's consultation
    (creating one on the fly if none exists yet).
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        provider = _provider_for_user(request.user)
        if not provider:
            return Response(
                {'error': 'Only providers can write prescriptions.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        appointment_id = request.data.get('appointment_id')
        medications = request.data.get('medications') or []
        instructions = request.data.get('instructions', '')

        if not appointment_id:
            return Response(
                {'error': 'appointment_id is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not isinstance(medications, list) or not medications:
            return Response(
                {'error': 'At least one medication is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            appointment = Appointment.objects.select_related(
                'patient', 'provider', 'patient__patient_id'
            ).get(appointment_id=appointment_id)
        except Appointment.DoesNotExist:
            return Response(
                {'error': 'Appointment not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if appointment.provider_id != provider.pk:
            return Response(
                {'error': 'You can only prescribe for your own patients.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        if appointment.status not in ('confirmed', 'completed'):
            return Response(
                {'error': 'Prescriptions require a confirmed or completed appointment.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        consultation, _ = Consultation.objects.get_or_create(
            appointment=appointment,
            defaults={'webrtc_session_id': str(uuid.uuid4())},
        )

        prescription = Prescription.objects.create(
            consultation=consultation,
            patient=appointment.patient,
            provider=provider,
            medications=medications,
            instructions=instructions,
            is_digital=True,
        )
        _create_reminders_from_prescription(prescription)
        _notify_patient_of_prescription(prescription)

        return Response(
            PrescriptionSerializer(prescription).data,
            status=status.HTTP_201_CREATED,
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


class ConsultationRingView(APIView):
    """Caller pings this when entering the video screen so we can FCM the
    peer with a high-priority "incoming_call" payload. Their app shows a
    full-screen incoming-call UI and plays the system ringtone.

    Body: optional {"audio_only": bool}.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            consultation = Consultation.objects.select_related(
                'appointment',
                'appointment__patient', 'appointment__patient__patient_id',
                'appointment__provider', 'appointment__provider__provider_id',
            ).get(pk=pk)
        except Consultation.DoesNotExist:
            return Response({'error': 'Consultation not found.'}, status=status.HTTP_404_NOT_FOUND)

        appointment = consultation.appointment
        patient_user = appointment.patient.patient_id
        provider_user = appointment.provider.provider_id
        caller = request.user

        if caller != patient_user and caller != provider_user:
            return Response({'error': 'You are not on this appointment.'}, status=status.HTTP_403_FORBIDDEN)

        peer = provider_user if caller == patient_user else patient_user
        caller_name = caller.full_name or 'Clinix'
        caller_photo = getattr(caller, 'profile_photo', '') or ''

        try:
            from apps.notifications.tasks import send_notification
            send_notification.delay(
                str(peer.user_id),
                f'Incoming call from {caller_name}',
                f'{caller_name} is calling you on Clinix.',
                'system',
                {
                    'type': 'incoming_call',
                    'consultation_id': str(consultation.consultation_id),
                    'caller_id': str(caller.user_id),
                    'caller_name': caller_name,
                    'caller_photo': caller_photo,
                    'audio_only': bool(request.data.get('audio_only')),
                },
            )
        except Exception:
            pass

        return Response({'status': 'ringing'}, status=status.HTTP_202_ACCEPTED)


class CallHistoryView(APIView):
    """Both sides' call log. Backed by Notification rows tagged with a
    `data.direction` key (incoming / outgoing), which is set by the missed-
    call view and could be set by future answered-call hooks too. Returns a
    flat list newest-first so the mobile can render a WhatsApp-style log.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from apps.notifications.models import Notification
        items = (
            Notification.objects
            .filter(user=request.user, data__direction__isnull=False)
            .order_by('-sent_at')[:100]
        )
        out = []
        for n in items:
            data = n.data or {}
            out.append({
                'id': str(n.notification_id),
                'title': n.title,
                'body': n.body,
                'direction': data.get('direction'),
                'reason': data.get('reason'),
                'caller_name': data.get('caller_name'),
                'consultation_id': data.get('consultation_id'),
                'appointment_id': data.get('appointment_id'),
                'sent_at': n.sent_at.isoformat() if n.sent_at else None,
                'is_read': n.is_read,
            })
        return Response(out)


class ConsultationMissedCallView(APIView):
    """Caller fires this when the 45-second no-answer timer expires so we can
    record the missed call on both sides. The receiver's CallKit already
    surfaces an OS-level missed-call notification (configured in the mobile
    app), so we don't push another FCM — we just persist Notification rows
    so the call shows up in each user's in-app inbox.

    Body: optional {"reason": "no_answer" | "declined"}.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            consultation = Consultation.objects.select_related(
                'appointment',
                'appointment__patient', 'appointment__patient__patient_id',
                'appointment__provider', 'appointment__provider__provider_id',
            ).get(pk=pk)
        except Consultation.DoesNotExist:
            return Response({'error': 'Consultation not found.'}, status=status.HTTP_404_NOT_FOUND)

        appointment = consultation.appointment
        patient_user = appointment.patient.patient_id
        provider_user = appointment.provider.provider_id
        caller = request.user

        if caller != patient_user and caller != provider_user:
            return Response({'error': 'You are not on this appointment.'}, status=status.HTTP_403_FORBIDDEN)

        peer = provider_user if caller == patient_user else patient_user
        caller_name = caller.full_name or 'Clinix'
        peer_name = peer.full_name or 'the other person'
        reason = request.data.get('reason', 'no_answer')

        try:
            from apps.notifications.models import Notification
            data = {
                'consultation_id': str(consultation.consultation_id),
                'appointment_id': str(appointment.appointment_id),
                'reason': reason,
            }
            # Caller's inbox: outgoing miss.
            Notification.objects.create(
                user=caller,
                title=f'No answer from {peer_name}',
                body='Tap to try again.',
                type='system',
                channel='in_app',
                data={**data, 'direction': 'outgoing'},
            )
            # Peer's inbox: incoming miss they didn't pick up.
            Notification.objects.create(
                user=peer,
                title=f'Missed call from {caller_name}',
                body='Tap to call back.',
                type='system',
                channel='in_app',
                data={**data, 'direction': 'incoming', 'caller_name': caller_name},
            )
        except Exception:
            pass

        return Response({'status': 'logged'}, status=status.HTTP_200_OK)


class ConsultationAudioUploadView(APIView):
    """Doctor-side audio upload after a consultation ends. The file is pushed
    to a Cloud Storage bucket on the SAME GCP project as Speech-to-Text
    (configured via GCP_AUDIO_BUCKET) using the same `clinix-stt` service
    account, so STT can read it without any cross-project IAM. The gs:// URI
    is stashed on the consultation; a Celery task then transcribes the
    audio via Google STT and asks Gemini to draft a structured medical
    record. Only the doctor on the appointment can upload."""
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [__import__('rest_framework.parsers', fromlist=['MultiPartParser']).MultiPartParser]

    def post(self, request, pk):
        import os
        provider = _provider_for_user(request.user)
        if not provider:
            return Response({'error': 'Only providers can upload call audio.'}, status=status.HTTP_403_FORBIDDEN)
        try:
            consultation = Consultation.objects.select_related('appointment', 'appointment__provider').get(pk=pk)
        except Consultation.DoesNotExist:
            return Response({'error': 'Consultation not found.'}, status=status.HTTP_404_NOT_FOUND)
        if consultation.appointment.provider_id != provider.pk:
            return Response({'error': 'You can only upload audio for your own consultations.'}, status=status.HTTP_403_FORBIDDEN)

        audio_file = request.FILES.get('audio') or request.FILES.get('file')
        if not audio_file:
            return Response({'error': 'No audio file provided.'}, status=status.HTTP_400_BAD_REQUEST)

        bucket_name = os.environ.get('GCP_AUDIO_BUCKET')
        if not bucket_name:
            return Response(
                {'error': 'GCP_AUDIO_BUCKET env var is not set on the server.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        try:
            from google.cloud import storage as gcs
            from .tasks import _gcp_credentials  # reuses the STT service-account JSON
            creds = _gcp_credentials()
            client = gcs.Client(credentials=creds, project=getattr(creds, 'project_id', None)) if creds else gcs.Client()
            bucket = client.bucket(bucket_name)
            blob_path = f'consultation_audio/{consultation.consultation_id}/{audio_file.name}'
            blob = bucket.blob(blob_path)
            blob.upload_from_file(
                audio_file,
                content_type=audio_file.content_type or 'audio/wav',
                rewind=True,
            )
            gs_uri = f'gs://{bucket_name}/{blob_path}'
        except Exception as e:
            return Response(
                {'error': f'Audio upload failed: {e}'},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        consultation.audio_gs_uri = gs_uri
        consultation.save(update_fields=['audio_gs_uri'])

        # Fire off the transcribe + draft job in the background.
        try:
            from .tasks import transcribe_and_draft_record
            transcribe_and_draft_record.delay(str(consultation.consultation_id))
        except Exception:
            pass

        return Response({'status': 'queued', 'audio_gs_uri': gs_uri}, status=status.HTTP_202_ACCEPTED)


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
        only_drafts = self.request.query_params.get('drafts') == '1'

        qs = MedicalRecord.objects.all()
        if provider and patient:
            base = qs.filter(
                Q(patient=patient, is_published=True) |
                Q(authored_by=provider) |
                Q(shared_with=provider, is_published=True)
            ).distinct()
            return base.filter(is_ai_draft=True, is_published=False) if only_drafts else base
        if provider:
            base = qs.filter(
                Q(authored_by=provider) |
                Q(shared_with=provider, is_published=True)
            ).distinct()
            return base.filter(is_ai_draft=True, is_published=False) if only_drafts else base
        if patient:
            # Patients never see unpublished AI drafts.
            return qs.filter(patient=patient, is_published=True)
        return MedicalRecord.objects.none()

    def perform_create(self, serializer):
        # Only providers can author records, and only for patients they have a
        # confirmed or completed appointment with.
        provider = _provider_for_user(self.request.user)
        if not provider:
            raise serializers.ValidationError('Only providers can author medical records.')

        patient = serializer.validated_data.get('patient')
        if not patient:
            raise serializers.ValidationError({'patient': 'patient is required.'})

        has_appointment = Appointment.objects.filter(
            provider=provider,
            patient=patient,
            status__in=['confirmed', 'completed'],
        ).exists()
        if not has_appointment:
            raise serializers.ValidationError(
                'You can only write a medical record for a patient you have a confirmed or completed appointment with.'
            )

        record = serializer.save(authored_by=provider)

        provider_name = (
            getattr(provider.provider_id, 'full_name', None) or 'Your doctor'
        )
        title_part = record.title or record.diagnosis or 'a new medical record'

        # FCM + in-app notification.
        try:
            from apps.notifications.tasks import send_notification
            send_notification.delay(
                record.patient.patient_id.user_id,
                'New medical record',
                f'{provider_name} added {title_part} to your medical records.',
                'medical_record',
                {'record_id': str(record.record_id)},
            )
        except Exception:
            pass

        # Inline chat message so the patient sees the record in chat too.
        try:
            from apps.direct_chat.clinical import post_clinical_message
            post_clinical_message(
                doctor_user=provider.provider_id,
                patient_user=record.patient.patient_id,
                message_type='medical_record',
                content=record.title or record.diagnosis or 'New medical record',
                metadata={
                    'record_id': str(record.record_id),
                    'diagnosis': (record.diagnosis or '')[:200],
                },
            )
        except Exception:
            pass


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
                Q(patient=patient, is_published=True) |
                Q(authored_by=provider) |
                Q(shared_with=provider, is_published=True)
            ).distinct()
        if provider:
            return qs.filter(
                Q(authored_by=provider) |
                Q(shared_with=provider, is_published=True)
            ).distinct()
        if patient:
            return qs.filter(patient=patient, is_published=True)
        return MedicalRecord.objects.none()

    def perform_update(self, serializer):
        was_unpublished = not serializer.instance.is_published
        record = serializer.save()
        # First time the doctor flips an AI draft to published, fire the
        # patient notification + chat card (the same way perform_create on
        # the list view does for non-AI records).
        if was_unpublished and record.is_published:
            provider = record.authored_by
            provider_name = (
                getattr(provider.provider_id, 'full_name', None) if provider else None
            ) or 'Your doctor'
            title_part = record.title or record.diagnosis or 'a new medical record'
            try:
                from apps.notifications.tasks import send_notification
                send_notification.delay(
                    record.patient.patient_id.user_id,
                    'New medical record',
                    f'{provider_name} added {title_part} to your medical records.',
                    'medical_record',
                    {'record_id': str(record.record_id)},
                )
            except Exception:
                pass
            try:
                from apps.direct_chat.clinical import post_clinical_message
                if provider:
                    post_clinical_message(
                        doctor_user=provider.provider_id,
                        patient_user=record.patient.patient_id,
                        message_type='medical_record',
                        content=record.title or record.diagnosis or 'New medical record',
                        metadata={
                            'record_id': str(record.record_id),
                            'diagnosis': (record.diagnosis or '')[:200],
                        },
                    )
            except Exception:
                pass


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


class PrescriptionShareView(APIView):
    """Patient grants or revokes another provider's view access to one of
    their prescriptions — useful when handing the script to a pharmacist or
    seeing a different doctor for a refill."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, prescription_id):
        patient = _patient_for_user(request.user)
        if not patient:
            return Response(
                {'error': 'Only patients can share prescriptions.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            prescription = Prescription.objects.get(
                prescription_id=prescription_id, patient=patient
            )
        except Prescription.DoesNotExist:
            return Response({'error': 'Prescription not found.'}, status=status.HTTP_404_NOT_FOUND)

        serializer = MedicalRecordShareSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            provider = HealthcareProvider.objects.get(provider_id=serializer.validated_data['provider_id'])
        except HealthcareProvider.DoesNotExist:
            return Response({'error': 'Provider not found.'}, status=status.HTTP_404_NOT_FOUND)

        if serializer.validated_data.get('revoke'):
            prescription.shared_with.remove(provider)
            return Response({'status': 'revoked', 'provider_id': str(provider.provider_id_id)})
        prescription.shared_with.add(provider)
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
        referral = serializer.save(referred_by=provider)

        provider_name = (
            getattr(provider.provider_id, 'full_name', None) or 'Your doctor'
        )
        if referral.kind == 'lab_test':
            target = referral.test_name or 'a lab test'
            body = f'{provider_name} referred you for {target}.'
        else:
            target = (
                getattr(getattr(referral.referred_to, 'provider_id', None), 'full_name', None)
                or referral.target_hospital_name
                or 'a specialist'
            )
            body = f'{provider_name} referred you to {target}.'

        # FCM + in-app notification.
        try:
            from apps.notifications.tasks import send_notification
            send_notification.delay(
                referral.patient.patient_id.user_id,
                'New referral',
                body,
                'referral',
                {'referral_id': str(referral.referral_id)},
            )
        except Exception:
            pass

        # Inline chat message.
        try:
            from apps.direct_chat.clinical import post_clinical_message
            post_clinical_message(
                doctor_user=provider.provider_id,
                patient_user=referral.patient.patient_id,
                message_type='referral',
                content=body,
                metadata={
                    'referral_id': str(referral.referral_id),
                    'kind': referral.kind,
                    'reason': (referral.reason or '')[:200],
                },
            )
        except Exception:
            pass


class ReferralDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = ReferralSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'referral_id'
    queryset = Referral.objects.all()
