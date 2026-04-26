from django.db import models
from apps.accounts.models import User
import uuid

class Notification(models.Model):
    TYPE_CHOICES = (
        ('appointment', 'Appointment'),
        ('consultation', 'Consultation'),
        ('verification', 'Verification'),
        ('payment', 'Payment'),
        ('system', 'System'),
        ('reminder', 'Reminder'),
        ('prescription', 'Prescription'),
        ('medical_record', 'Medical Record'),
        ('medication_reminder', 'Medication Reminder'),
    )

    CHANNEL_CHOICES = (
        ('push', 'Push'),
        ('sms', 'SMS'),
        ('email', 'Email'),
        ('in_app', 'In-App'),
    )

    notification_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    title = models.CharField(max_length=255, blank=True, null=True)
    body = models.TextField(blank=True, null=True)
    data = models.JSONField(blank=True, null=True)
    is_read = models.BooleanField(default=False)
    channel = models.CharField(max_length=20, choices=CHANNEL_CHOICES)
    sent_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notifications'
