from rest_framework import serializers
from .models import HealthcareProvider, ProviderCredential
from apps.accounts.serializers import UserSerializer
from apps.locations.models import Location

class LocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Location
        fields = '__all__'

class ProviderProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(source='provider_id', read_only=True)
    location = LocationSerializer(read_only=True)
    
    class Meta:
        model = HealthcareProvider
        fields = '__all__'
        read_only_fields = ('provider_id', 'verification_status', 'verification_notes', 'verified_at', 'verified_by', 'rating', 'total_consultations')

class ProviderPublicSerializer(serializers.ModelSerializer):
    user_first_name = serializers.CharField(source='provider_id.first_name', read_only=True)
    user_last_name = serializers.CharField(source='provider_id.last_name', read_only=True)
    user_photo = serializers.URLField(source='provider_id.profile_photo', read_only=True)
    location = LocationSerializer(read_only=True)
    
    class Meta:
        model = HealthcareProvider
        fields = ('provider_id', 'user_first_name', 'user_last_name', 'user_photo', 'specialization', 'years_experience', 'bio', 'consultation_fee', 'is_available', 'rating', 'total_consultations', 'location')
        
class ProviderCredentialSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProviderCredential
        fields = '__all__'
        read_only_fields = ('provider', 'is_verified', 'uploaded_at')
