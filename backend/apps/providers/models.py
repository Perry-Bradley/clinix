from django.db import models
from apps.accounts.models import User
import uuid

class HealthcareProvider(models.Model):
    VERIFICATION_CHOICES = (
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('suspended', 'Suspended'),
    )

    provider_id = models.OneToOneField(User, on_delete=models.CASCADE, primary_key=True, db_column='provider_id')
    specialization = models.CharField(max_length=200)
    license_number = models.CharField(max_length=100, unique=True)
    years_experience = models.IntegerField(null=True, blank=True)
    bio = models.TextField(blank=True, null=True)
    consultation_fee = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    
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

class ProviderCredential(models.Model):
    DOC_TYPE_CHOICES = (
        ('license', 'License'),
        ('degree', 'Degree'),
        ('certificate', 'Certificate'),
        ('id', 'ID'),
    )

    credential_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider = models.ForeignKey(HealthcareProvider, on_delete=models.CASCADE, related_name='credentials')
    document_type = models.CharField(max_length=20, choices=DOC_TYPE_CHOICES)
    document_url = models.URLField(max_length=500)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    is_verified = models.BooleanField(default=False)

    class Meta:
        db_table = 'provider_credentials'

    def __str__(self):
        return f"{self.provider} - {self.document_type}"
