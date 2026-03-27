from django.db import models
from apps.providers.models import HealthcareProvider
import uuid

class Location(models.Model):
    location_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider = models.OneToOneField(HealthcareProvider, on_delete=models.CASCADE, related_name='location')
    facility_name = models.CharField(max_length=300, blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    region = models.CharField(max_length=100, blank=True, null=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    is_home_visit = models.BooleanField(default=False)

    class Meta:
        db_table = 'locations'

    def __str__(self):
        return f"Location for {self.provider}"
