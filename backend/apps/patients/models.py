from django.db import models
from apps.accounts.models import User
from django.contrib.postgres.fields import ArrayField
import uuid

class Patient(models.Model):
    GENDER_CHOICES = (
        ('male', 'Male'),
        ('female', 'Female'),
        ('other', 'Other'),
    )

    patient_id = models.OneToOneField(User, on_delete=models.CASCADE, primary_key=True, db_column='patient_id')
    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=10, choices=GENDER_CHOICES, null=True, blank=True)
    blood_type = models.CharField(max_length=5, blank=True, null=True)
    allergies = ArrayField(models.TextField(), blank=True, default=list)
    chronic_conditions = ArrayField(models.TextField(), blank=True, default=list)
    emergency_contact_name = models.CharField(max_length=200, blank=True, null=True)
    emergency_contact_phone = models.CharField(max_length=20, blank=True, null=True)
    next_of_kin = models.CharField(max_length=200, blank=True, null=True)

    # Baseline health data the patient fills in after signup (and can edit
    # any time in their profile). Shown to the doctor before a consultation
    # so they start with basic context about the patient.
    height_cm = models.DecimalField(max_digits=5, decimal_places=1, null=True, blank=True)
    weight_kg = models.DecimalField(max_digits=5, decimal_places=1, null=True, blank=True)
    temperature_c = models.DecimalField(max_digits=4, decimal_places=1, null=True, blank=True)
    pulse_bpm = models.PositiveIntegerField(null=True, blank=True)
    current_medications = models.TextField(blank=True, default='')
    health_profile_completed = models.BooleanField(default=False)

    class Meta:
        db_table = 'patients'

    def __str__(self):
        return str(self.patient_id)
