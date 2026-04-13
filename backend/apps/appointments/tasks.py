from celery import shared_task
from django.utils import timezone
from datetime import timedelta
from .models import Appointment
from apps.notifications.tasks import send_notification

@shared_task
def send_appointment_reminders():
    # Find appointments happening in the next 24 hours
    now = timezone.now()
    timerange_start = now + timedelta(hours=23)
    timerange_end = now + timedelta(hours=25)
    
    upcoming_appointments = Appointment.objects.filter(
        status='confirmed',
        scheduled_at__range=(timerange_start, timerange_end)
    )
    
    for appointment in upcoming_appointments:
        title = "Upcoming Appointment Reminder"
        provider_name = appointment.provider.provider_id.full_name or 'your provider'
        appointment_type = appointment.appointment_type.replace('-', ' ')
        message = f"You have an upcoming {appointment_type} appointment with {provider_name} on {appointment.scheduled_at.strftime('%b %d, %H:%M')}."
        # Send to patient
        send_notification.delay(
            appointment.patient.patient_id.user_id,
            title,
            message,
            'appointment'
        )
        appointment.reminder_sent = True
        appointment.save(update_fields=['reminder_sent'])
