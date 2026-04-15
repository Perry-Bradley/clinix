from rest_framework import serializers
from .models import HealthcareProvider, ProviderCredential, ProviderSchedule, ProviderReview
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
    profile_photo = serializers.URLField(write_only=True, required=False, allow_blank=True, allow_null=True)
    full_name = serializers.CharField(write_only=True, required=False, allow_blank=True, allow_null=True)

    class Meta:
        model = HealthcareProvider
        fields = '__all__'
        read_only_fields = ('provider_id', 'verification_status', 'verification_notes', 'verified_at', 'verified_by', 'rating', 'total_consultations')

    def update(self, instance, validated_data):
        # Pull out user-level fields and update them on the linked User model
        profile_photo = validated_data.pop('profile_photo', None)
        full_name = validated_data.pop('full_name', None)
        user = instance.provider_id
        updated_user_fields = []
        if profile_photo is not None:
            user.profile_photo = profile_photo
            updated_user_fields.append('profile_photo')
        if full_name:
            user.full_name = full_name
            updated_user_fields.append('full_name')
        if updated_user_fields:
            user.save(update_fields=updated_user_fields)
        return super().update(instance, validated_data)

class ProviderPublicSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source='provider_id.full_name', read_only=True)
    user_photo = serializers.URLField(source='provider_id.profile_photo', read_only=True)
    locations = LocationSerializer(many=True, read_only=True)
    schedules = ProviderScheduleSerializer(many=True, read_only=True)
    review_count = serializers.IntegerField(source='reviews.count', read_only=True)
    status = serializers.SerializerMethodField()

    def get_status(self, obj):
        from django.utils import timezone
        last_seen = obj.provider_id.last_seen
        if not last_seen:
            return 'Offline'
        diff = (timezone.now() - last_seen).total_seconds()
        if diff < 300:  # 5 minutes
            return 'Online'
        if diff < 1800:  # 30 minutes
            return 'Away'
        return 'Offline'

    class Meta:
        model = HealthcareProvider
        fields = ('provider_id', 'full_name', 'user_photo', 'specialty', 'other_specialty', 'years_experience', 'bio', 'consultation_fee', 'is_available', 'rating', 'total_consultations', 'review_count', 'status', 'locations', 'schedules')
        
class ProviderCredentialSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField(read_only=True)

    def get_file_url(self, obj):
        request = self.context.get('request')
        url = obj.document_url
        if request and url and not str(url).startswith('http'):
            return request.build_absolute_uri(url)
        return url

    class Meta:
        model = ProviderCredential
        fields = '__all__'
        read_only_fields = ('provider', 'is_verified', 'uploaded_at')

class ProviderReviewSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.patient_id.full_name', read_only=True)

    class Meta:
        model = ProviderReview
        fields = ('review_id', 'rating', 'comment', 'created_at', 'patient_name')

class ProviderReviewCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProviderReview
        fields = ('appointment', 'rating', 'comment')
