from django.db import models
from apps.patients.models import Patient
from apps.providers.models import HealthcareProvider
import uuid

class Appointment(models.Model):
    TYPE_CHOICES = (
        ('virtual', 'Virtual'),
        ('in-person', 'In-Person'),
    )

    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('cancelled', 'Cancelled'),
        ('completed', 'Completed'),
        ('no_show', 'No Show'),
    )

    appointment_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='appointments')
    provider = models.ForeignKey(HealthcareProvider, on_delete=models.CASCADE, related_name='appointments')
    scheduled_at = models.DateTimeField()
    duration_minutes = models.IntegerField(default=30)
    appointment_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='virtual')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    cancellation_reason = models.TextField(blank=True, null=True)
    reminder_sent = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'appointments'

    def __str__(self):
        return f"{self.patient} with {self.provider} at {self.scheduled_at}"
