from django.db import models
from apps.providers.models import HealthcareProvider
import uuid

class Location(models.Model):
    LOCATION_TYPES = (
        ('residence', 'Residence'),
        ('clinic', 'Clinic'),
    )

    location_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider = models.ForeignKey(HealthcareProvider, on_delete=models.CASCADE, related_name='locations')
    location_type = models.CharField(max_length=20, choices=LOCATION_TYPES, default='residence')
    facility_name = models.CharField(max_length=300, blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    region = models.CharField(max_length=100, blank=True, null=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    phone_number = models.CharField(max_length=20, blank=True, null=True, help_text='Contact phone number for the facility')
    is_home_visit = models.BooleanField(default=False)

    class Meta:
        db_table = 'locations'

    def __str__(self):
        return f"Location for {self.provider}"


class Pharmacy(models.Model):
    PLACE_TYPES = (
        ('pharmacy', 'Pharmacy'),
        ('hospital', 'Hospital'),
    )

    place_id = models.CharField(max_length=255, unique=True)
    name = models.CharField(max_length=300)
    place_type = models.CharField(max_length=20, choices=PLACE_TYPES, default='pharmacy')
    address = models.TextField(blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    phone_number = models.CharField(max_length=30, blank=True, null=True)
    synced_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'pharmacies'
        ordering = ['city', 'name']

    def __str__(self):
        return f"{self.name} ({self.city})"
