from rest_framework import serializers
from .models import User
from apps.patients.models import Patient
from apps.providers.models import HealthcareProvider

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('user_id', 'phone_number', 'email', 'user_type', 'first_name', 'last_name', 'profile_photo', 'language_pref', 'is_verified')
        read_only_fields = ('user_id', 'user_type', 'is_verified')

class PatientRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    
    class Meta:
        model = User
        fields = ('phone_number', 'password', 'first_name', 'last_name', 'language_pref')

    def create(self, validated_data):
        user = User.objects.create_user(
            phone_number=validated_data['phone_number'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
            language_pref=validated_data.get('language_pref', 'en'),
            user_type='patient'
        )
        Patient.objects.create(patient_id=user)
        return user

class ProviderRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    specialization = serializers.CharField(max_length=200)
    license_number = serializers.CharField(max_length=100)
    
    class Meta:
        model = User
        fields = ('phone_number', 'password', 'first_name', 'last_name', 'specialization', 'license_number')

    def create(self, validated_data):
        specialization = validated_data.pop('specialization')
        license_number = validated_data.pop('license_number')
        
        user = User.objects.create_user(
            phone_number=validated_data['phone_number'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
            user_type='provider'
        )
        HealthcareProvider.objects.create(
            provider_id=user,
            specialization=specialization,
            license_number=license_number
        )
        return user

class OTPSendSerializer(serializers.Serializer):
    phone_number = serializers.CharField()

class OTPVerifySerializer(serializers.Serializer):
    phone_number = serializers.CharField()
    otp = serializers.CharField()

class PasswordResetConfirmSerializer(serializers.Serializer):
    phone_number = serializers.CharField()
    otp = serializers.CharField()
    new_password = serializers.CharField()
