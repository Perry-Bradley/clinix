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
