from rest_framework import serializers
from .models import HealthcareProvider, ProviderCredential, ProviderSchedule
from apps.accounts.serializers import UserSerializer
from apps.locations.models import Location

class ProviderScheduleSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProviderSchedule
        fields = ('day', 'start_time', 'end_time', 'is_working')

class LocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Location
        fields = ('location_id', 'location_type', 'facility_name', 'address', 'city', 'region', 'latitude', 'longitude', 'is_home_visit')

class ProviderProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(source='provider_id', read_only=True)
    locations = LocationSerializer(many=True, read_only=True)
    schedules = ProviderScheduleSerializer(many=True, read_only=True)
    
    class Meta:
        model = HealthcareProvider
        fields = '__all__'
        read_only_fields = ('provider_id', 'verification_status', 'verification_notes', 'verified_at', 'verified_by', 'rating', 'total_consultations')

class ProviderPublicSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source='provider_id.full_name', read_only=True)
    user_photo = serializers.URLField(source='provider_id.profile_photo', read_only=True)
    locations = LocationSerializer(many=True, read_only=True)
    schedules = ProviderScheduleSerializer(many=True, read_only=True)
    
    class Meta:
        model = HealthcareProvider
        fields = ('provider_id', 'full_name', 'user_photo', 'specialty', 'other_specialty', 'years_experience', 'bio', 'consultation_fee', 'is_available', 'rating', 'total_consultations', 'locations', 'schedules')
        
class ProviderCredentialSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProviderCredential
        fields = '__all__'
        read_only_fields = ('provider', 'is_verified', 'uploaded_at')
