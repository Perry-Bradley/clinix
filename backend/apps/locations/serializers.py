from rest_framework import serializers
from .models import Location
from apps.providers.models import HealthcareProvider

class LocationUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Location
        fields = ('latitude', 'longitude', 'is_home_visit', 'city', 'region', 'address', 'facility_name')
