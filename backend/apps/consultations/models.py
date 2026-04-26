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
    # Plain-text transcript produced by Google Cloud Speech-to-Text after the
    # call ends. Feeds straight into Gemini for the AI medical-record draft.
    call_transcript = models.TextField(blank=True, default='')
    # gs:// URI of the uploaded audio in Firebase Storage; the STT job picks
    # the audio up from here so we don't have to round-trip megabytes back to
    # the worker.
    audio_gs_uri = models.CharField(max_length=500, blank=True, default='')
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
    # Patient-controlled sharing — providers the patient has granted view
    # access to this prescription (e.g. when being referred to a pharmacy
    # or another doctor for a follow-up).
    shared_with = models.ManyToManyField(
        HealthcareProvider, blank=True, related_name='shared_prescriptions',
    )

    class Meta:
        db_table = 'prescriptions'


class MedicationReminder(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    prescription = models.ForeignKey(Prescription, on_delete=models.CASCADE, related_name='reminders')
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='medication_reminders')
    medication_name = models.CharField(max_length=200)
    dosage = models.CharField(max_length=100)
    frequency = models.CharField(max_length=100)
    reminder_times = models.JSONField(default=list, help_text='List of HH:MM times for daily reminders')
    start_date = models.DateField()
    end_date = models.DateField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['medication_name']

    def __str__(self):
        return f"{self.medication_name} for {self.patient}"


class MedicationLog(models.Model):
    STATUS_CHOICES = [('taken', 'Taken'), ('skipped', 'Skipped'), ('missed', 'Missed')]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reminder = models.ForeignKey(MedicationReminder, on_delete=models.CASCADE, related_name='logs')
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='medication_logs')
    scheduled_time = models.DateTimeField()
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='missed')
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-scheduled_time']
        unique_together = ['reminder', 'scheduled_time']


class MedicalRecord(models.Model):
    """Doctor-authored consultation report. Belongs to the patient and can be
    shared with other providers when the patient is referred elsewhere."""
    record_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='medical_records')
    consultation = models.ForeignKey(Consultation, on_delete=models.SET_NULL, null=True, blank=True, related_name='medical_records')
    authored_by = models.ForeignKey(
        HealthcareProvider, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='authored_records',
    )
    title = models.CharField(max_length=200, blank=True, null=True)
    chief_complaint = models.TextField(blank=True, null=True)
    symptoms = ArrayField(models.TextField(), blank=True, default=list)
    symptom_duration = models.CharField(max_length=100, blank=True, null=True)
    examination_findings = models.TextField(blank=True, null=True)
    diagnosis = models.TextField(blank=True, null=True)
    treatment_plan = models.TextField(blank=True, null=True)
    medications_summary = models.TextField(blank=True, null=True)
    follow_up_date = models.DateField(null=True, blank=True)
    attachments = ArrayField(models.TextField(), blank=True, default=list) # S3/Cloudinary URLs
    # Patient-controlled sharing — doctors that the patient has granted view access.
    shared_with = models.ManyToManyField(
        HealthcareProvider, blank=True, related_name='shared_records',
    )
    # AI-drafted records start as unpublished drafts, visible only to the
    # authoring doctor. The doctor reviews + submits, which sets is_ai_draft
    # back to False (or keeps it True for transparency) and is_published=True.
    # The patient list query below filters on is_published.
    is_ai_draft = models.BooleanField(default=False)
    is_published = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'medical_records'
        ordering = ['-created_at']


class Referral(models.Model):
    """A referral issued by a doctor — either to another specialist on the
    platform, or to a specific hospital for a lab test / procedure."""
    KIND_CHOICES = (
        ('specialist', 'Specialist'),
        ('lab_test', 'Lab Test'),
    )
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    )

    referral_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    kind = models.CharField(max_length=20, choices=KIND_CHOICES)
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='referrals')
    referred_by = models.ForeignKey(
        HealthcareProvider, on_delete=models.SET_NULL, null=True,
        related_name='outgoing_referrals',
    )
    referred_to = models.ForeignKey(
        HealthcareProvider, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='incoming_referrals',
    )
    target_hospital_name = models.CharField(max_length=200, blank=True, null=True)
    target_hospital_address = models.CharField(max_length=300, blank=True, null=True)
    target_hospital_place_id = models.CharField(max_length=200, blank=True, null=True)
    test_name = models.CharField(max_length=200, blank=True, null=True)
    reason = models.TextField()
    medical_record = models.ForeignKey(
        MedicalRecord, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='referrals',
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'referrals'
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.kind} referral for {self.patient} ({self.status})'


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
