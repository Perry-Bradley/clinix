import logging
from datetime import date, datetime, timedelta
from django.utils import timezone

logger = logging.getLogger(__name__)

try:
    from celery import shared_task
except ImportError:
    # Celery not installed locally — define a no-op decorator
    def shared_task(fn):
        return fn


@shared_task
def send_medication_reminders():
    """
    Runs every 15 minutes via Celery Beat.
    Checks all active reminders, finds any whose scheduled time is within
    the current 15-minute window, creates a MedicationLog (status=missed),
    and sends a push notification. Patient confirms/skips via the app.
    """
    from .models import MedicationReminder, MedicationLog
    from apps.notifications.tasks import send_notification

    now = timezone.localtime()
    current_time = now.strftime('%H:%M')
    current_hour = int(current_time.split(':')[0])
    current_min = int(current_time.split(':')[1])
    today = date.today()

    reminders = MedicationReminder.objects.filter(
        is_active=True,
        start_date__lte=today,
        end_date__gte=today,
    )

    for reminder in reminders:
        for time_str in (reminder.reminder_times or []):
            try:
                h, m = int(time_str.split(':')[0]), int(time_str.split(':')[1])
            except (ValueError, IndexError):
                continue

            # Check if this reminder time is within the current 15-min window
            reminder_minutes = h * 60 + m
            current_minutes = current_hour * 60 + current_min
            diff = abs(current_minutes - reminder_minutes)
            if diff > 7:  # ±7 minutes tolerance
                continue

            # Create log entry if not already created for this time today
            scheduled_dt = timezone.make_aware(
                datetime(now.year, now.month, now.day, h, m),
                timezone.get_current_timezone(),
            )
            _, created = MedicationLog.objects.get_or_create(
                reminder=reminder,
                scheduled_time=scheduled_dt,
                defaults={'patient': reminder.patient, 'status': 'missed'},
            )

            if created:
                # Send push notification
                user_id = str(reminder.patient.patient_id.user_id)
                send_notification.delay(
                    user_id=user_id,
                    title='Medication Reminder',
                    body=f"Time to take {reminder.medication_name} ({reminder.dosage})",
                    notification_type='medication_reminder',
                    data={'reminder_id': str(reminder.id)},
                )
                logger.info(f"Sent reminder for {reminder.medication_name} to patient {user_id}")


@shared_task
def transcribe_and_draft_record(consultation_id: str):
    """Pull the audio uploaded to Firebase Storage for this consultation, run
    Google Cloud Speech-to-Text on it, hand the transcript to Gemini for a
    medical-record draft, and notify the doctor that the AI draft is ready.

    The doctor reviews + edits the draft on `/provider/medical-record/new`
    before submitting (which publishes it to the patient).
    """
    from .models import Consultation, MedicalRecord
    from apps.notifications.tasks import send_notification
    from apps.ai_engine.medlm_client import medlm_client

    try:
        consultation = Consultation.objects.select_related(
            'appointment', 'appointment__patient', 'appointment__patient__patient_id',
            'appointment__provider', 'appointment__provider__provider_id',
        ).get(consultation_id=consultation_id)
    except Consultation.DoesNotExist:
        logger.warning(f'transcribe_and_draft: consultation {consultation_id} not found')
        return

    audio_uri = consultation.audio_gs_uri
    if not audio_uri:
        logger.warning(f'transcribe_and_draft: no audio_gs_uri on {consultation_id}')
        return

    transcript = _run_speech_to_text(audio_uri)
    if not transcript:
        logger.warning(f'transcribe_and_draft: empty transcript for {consultation_id}')
        return

    consultation.call_transcript = transcript
    consultation.save(update_fields=['call_transcript'])

    try:
        draft = medlm_client.draft_medical_record(transcript)
    except Exception as e:
        logger.exception(f'transcribe_and_draft: Gemini draft failed for {consultation_id}: {e}')
        return

    provider = consultation.appointment.provider
    patient = consultation.appointment.patient

    # Persist as an unpublished draft so it doesn't surface to the patient.
    record = MedicalRecord.objects.create(
        patient=patient,
        consultation=consultation,
        authored_by=provider,
        title=draft.get('title', '') or '',
        chief_complaint=draft.get('chief_complaint', '') or '',
        symptoms=draft.get('symptoms') or [],
        symptom_duration=draft.get('symptom_duration', '') or '',
        examination_findings=draft.get('examination_findings', '') or '',
        diagnosis=draft.get('diagnosis', '') or '',
        treatment_plan=draft.get('treatment_plan', '') or '',
        medications_summary=draft.get('medications_summary', '') or '',
        is_ai_draft=True,
        is_published=False,
    )

    # Try to set follow_up_date if the model returned a parseable one.
    raw_followup = draft.get('follow_up_date', '')
    if raw_followup:
        try:
            record.follow_up_date = datetime.strptime(str(raw_followup), '%Y-%m-%d').date()
            record.save(update_fields=['follow_up_date'])
        except Exception:
            pass

    patient_name = (
        getattr(patient.patient_id, 'full_name', None) or 'your patient'
    )
    send_notification.delay(
        str(provider.provider_id.user_id),
        'AI report draft ready',
        f'Your draft report for {patient_name} is ready — review and submit.',
        'medical_record',
        {
            'record_id': str(record.record_id),
            'is_ai_draft': True,
            'consultation_id': str(consultation.consultation_id),
        },
    )
    logger.info(f'transcribe_and_draft: draft {record.record_id} ready for provider')


def _run_speech_to_text(audio_gs_uri: str) -> str:
    """Long-running Google Cloud Speech-to-Text recognise. Audio is read from
    a `gs://...` URI in Firebase Storage. Detects English/French and returns
    the joined transcript text."""
    try:
        from google.cloud import speech_v1 as speech
    except ImportError:
        logger.error('google-cloud-speech is not installed; cannot transcribe.')
        return ''

    try:
        client = speech.SpeechClient()
        audio = speech.RecognitionAudio(uri=audio_gs_uri)
        config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
            sample_rate_hertz=16000,
            language_code='en-US',
            alternative_language_codes=['fr-FR'],
            enable_automatic_punctuation=True,
            model='medical_conversation',
            use_enhanced=True,
        )
        operation = client.long_running_recognize(config=config, audio=audio)
        # Wait up to 10 min for the transcription to finish — well over the
        # length of any sane consultation.
        response = operation.result(timeout=600)
        parts = []
        for result in response.results:
            if result.alternatives:
                parts.append(result.alternatives[0].transcript.strip())
        return ' '.join(parts).strip()
    except Exception:
        # Fall back to the standard model — `medical_conversation` requires
        # the medical add-on to be enabled on the GCP project; if it's not,
        # try again without it so v1 still works on a vanilla project.
        try:
            from google.cloud import speech_v1 as speech
            client = speech.SpeechClient()
            audio = speech.RecognitionAudio(uri=audio_gs_uri)
            config = speech.RecognitionConfig(
                encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
                sample_rate_hertz=16000,
                language_code='en-US',
                alternative_language_codes=['fr-FR'],
                enable_automatic_punctuation=True,
            )
            operation = client.long_running_recognize(config=config, audio=audio)
            response = operation.result(timeout=600)
            parts = []
            for result in response.results:
                if result.alternatives:
                    parts.append(result.alternatives[0].transcript.strip())
            return ' '.join(parts).strip()
        except Exception as e:
            logger.exception(f'Google Speech-to-Text failed: {e}')
            return ''
