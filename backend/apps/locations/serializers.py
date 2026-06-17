from rest_framework import serializers
from .models import Location
from apps.providers.models import HealthcareProvider

class LocationUpdateSerializer(serializers.ModelSerializer):
    # Phones send high-precision GPS coordinates (often 8+ decimal places),
    # which a DecimalField(decimal_places=7) rejects with a 400. Accept them as
    # floats and let the model/DB round to its stored precision.
    latitude = serializers.FloatField(required=False, allow_null=True)
    longitude = serializers.FloatField(required=False, allow_null=True)

    class Meta:
        model = Location
        fields = (
            'location_type',
            'latitude',
            'longitude',
            'is_home_visit',
            'city',
            'region',
            'address',
            'facility_name',
            'phone_number',
        )
