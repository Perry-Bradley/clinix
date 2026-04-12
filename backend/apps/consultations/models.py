from django.db import models
from apps.appointments.models import Appointment
from apps.patients.models import Patient
from apps.providers.models import HealthcareProvider
from django.contrib.postgres.fields import ArrayField
import uuid

class Consultation(models.Model):
    TYPE_CHOICES = (
        ('ai_only', 'AI Only'),
        ('provider', 'Provider'),
        ('hybrid', 'Hybrid'),
    )

    consultation_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    appointment = models.OneToOneField(Appointment, on_delete=models.CASCADE, related_name='consultation')
    started_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    ai_transcript = models.JSONField(blank=True, null=True)
    provider_notes = models.TextField(blank=True, null=True)
    diagnosis = models.TextField(blank=True, null=True)
    ai_recommendation = models.TextField(blank=True, null=True)
    consultation_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='hybrid')
    webrtc_session_id = models.CharField(max_length=255, blank=True, null=True)
    recording_url = models.URLField(max_length=500, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'consultations'


class Prescription(models.Model):
    prescription_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    consultation = models.ForeignKey(Consultation, on_delete=models.CASCADE, related_name='prescriptions')
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='prescriptions')
    provider = models.ForeignKey(HealthcareProvider, on_delete=models.CASCADE, related_name='prescriptions')
    medications = models.JSONField() # [{name, dosage, frequency, duration}]
    instructions = models.TextField(blank=True, null=True)
    is_digital = models.BooleanField(default=True)
    issued_at = models.DateTimeField(auto_now_add=True)
    valid_until = models.DateField(null=True, blank=True)

    class Meta:
        db_table = 'prescriptions'


class MedicalRecord(models.Model):
    record_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='medical_records')
    consultation = models.ForeignKey(Consultation, on_delete=models.SET_NULL, null=True, blank=True, related_name='medical_records')
    symptoms = ArrayField(models.TextField(), blank=True, default=list)
    symptom_duration = models.CharField(max_length=100, blank=True, null=True)
    diagnosis = models.TextField(blank=True, null=True)
    treatment_plan = models.TextField(blank=True, null=True)
    follow_up_date = models.DateField(null=True, blank=True)
    attachments = ArrayField(models.TextField(), blank=True, default=list) # S3/Cloudinary URLs
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'medical_records'


class ChatMessage(models.Model):
    MESSAGE_TYPES = (
        ('text', 'Text'),
        ('image', 'Image'),
        ('file', 'File'),
    )

    message_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    consultation = models.ForeignKey(Consultation, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='chat_messages')
    
    message_type = models.CharField(max_length=10, choices=MESSAGE_TYPES, default='text')
    content = models.TextField(blank=True, null=True) # Text content or caption
    file_url = models.URLField(max_length=1000, blank=True, null=True)
    file_name = models.CharField(max_length=255, blank=True, null=True)
    
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'chat_messages'
        ordering = ['created_at']

    def __str__(self):
        return f"Message from {self.sender} in {self.consultation}"
