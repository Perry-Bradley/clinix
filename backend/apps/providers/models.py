from django.db import models
from apps.accounts.models import User
from apps.patients.models import Patient
import uuid


class Specialty(models.Model):
    """Admin-configured catalogue of medical specialties.

    Used to populate the provider signup dropdown for specialists and to
    filter doctor lookups when the AI recommends a doctor for a patient's
    case.
    """
    specialty_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=120, unique=True)
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'specialties'
        ordering = ['name']

    def __str__(self):
        return self.name


class HealthcareProvider(models.Model):
    VERIFICATION_CHOICES = (
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('suspended', 'Suspended'),
    )

    SPECIALTY_CHOICES = (
        ('generalist', 'Generalist'),
        ('nurse', 'Nurse'),
        ('midwife', 'Midwife'),
        ('other', 'Other'),
    )

    PROVIDER_ROLE_CHOICES = (
        ('generalist', 'Generalist'),
        ('specialist', 'Specialist'),
        ('nurse', 'Nurse'),
    )

    provider_id = models.OneToOneField(User, on_delete=models.CASCADE, primary_key=True, db_column='provider_id')
    specialty = models.CharField(max_length=50, choices=SPECIALTY_CHOICES, default='generalist')
    other_specialty = models.CharField(max_length=200, blank=True, null=True)
    # New: structured role + admin-configured specialty
    provider_role = models.CharField(max_length=20, choices=PROVIDER_ROLE_CHOICES, default='generalist')
    specialty_obj = models.ForeignKey(
        Specialty, on_delete=models.SET_NULL, null=True, blank=True, related_name='providers',
    )
    license_number = models.CharField(max_length=100, unique=True)
    years_experience = models.IntegerField(default=0)
    bio = models.TextField(blank=True, null=True)
    consultation_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    
    verification_status = models.CharField(max_length=20, choices=VERIFICATION_CHOICES, default='pending')
    verification_notes = models.TextField(blank=True, null=True)
    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='verified_providers')
    
    is_available = models.BooleanField(default=False)
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.00)
    total_consultations = models.IntegerField(default=0)

    class Meta:
        db_table = 'healthcare_providers'

    def __str__(self):
        return str(self.provider_id)

class ProviderSchedule(models.Model):
    DAYS_OF_WEEK = (
        ('monday', 'Monday'),
        ('tuesday', 'Tuesday'),
        ('wednesday', 'Wednesday'),
        ('thursday', 'Thursday'),
        ('friday', 'Friday'),
        ('saturday', 'Saturday'),
        ('sunday', 'Sunday'),
    )

    schedule_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider = models.ForeignKey(HealthcareProvider, on_delete=models.CASCADE, related_name='schedules')
    day = models.CharField(max_length=20, choices=DAYS_OF_WEEK)
    start_time = models.TimeField()
    end_time = models.TimeField()
    is_working = models.BooleanField(default=True)

    class Meta:
        db_table = 'provider_schedules'
        unique_together = ('provider', 'day')

    def __str__(self):
        return f"{self.provider} - {self.day} ({self.start_time} to {self.end_time})"

class ProviderCredential(models.Model):
    DOC_TYPE_CHOICES = (
        ('national_id_front', 'National ID Front'),
        ('national_id_back', 'National ID Back'),
        ('medical_license', 'Medical License'),
    )

    credential_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider = models.ForeignKey(HealthcareProvider, on_delete=models.CASCADE, related_name='credentials')
    document_type = models.CharField(max_length=20, choices=DOC_TYPE_CHOICES)
    document_url = models.URLField(max_length=1024)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    is_verified = models.BooleanField(default=False)

    class Meta:
        db_table = 'provider_credentials'

    def __str__(self):
        return f"{self.provider} - {self.document_type}"

class ProviderReview(models.Model):
    review_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider = models.ForeignKey(HealthcareProvider, on_delete=models.CASCADE, related_name='reviews')
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='provider_reviews')
    appointment = models.ForeignKey('appointments.Appointment', on_delete=models.SET_NULL, null=True, blank=True, related_name='provider_reviews')
    rating = models.PositiveSmallIntegerField()
    comment = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'provider_reviews'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.provider} - {self.rating}/5"
