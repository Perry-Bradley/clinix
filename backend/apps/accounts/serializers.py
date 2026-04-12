from rest_framework import serializers
from .models import User
from apps.patients.models import Patient
from apps.providers.models import HealthcareProvider

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('user_id', 'phone_number', 'email', 'user_type', 'full_name', 'profile_photo', 'language_pref', 'is_verified')
        read_only_fields = ('user_id', 'user_type', 'is_verified')

class BasicRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    identifier = serializers.CharField(write_only=True) # Email or Phone
    
    class Meta:
        model = User
        fields = ('identifier', 'password', 'full_name')

    def create(self, validated_data):
        identifier = validated_data.pop('identifier')
        password = validated_data.pop('password')
        full_name = validated_data.get('full_name', '')
        
        email = None
        phone_number = None
        
        if '@' in identifier:
            email = identifier
        else:
            phone_number = identifier
            
        user = User.objects.create_user(
            email=email,
            phone_number=phone_number,
            password=password,
            full_name=full_name,
            user_type='unassigned'
        )
        return user

class RoleSelectionSerializer(serializers.Serializer):
    user_type = serializers.ChoiceField(choices=['patient', 'provider'])

class PatientRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    
    class Meta:
        model = User
        fields = ('phone_number', 'email', 'password', 'full_name', 'language_pref')

    def create(self, validated_data):
        user = User.objects.create_user(
            phone_number=validated_data.get('phone_number'),
            email=validated_data.get('email'),
            password=validated_data['password'],
            full_name=validated_data.get('full_name', ''),
            language_pref=validated_data.get('language_pref', 'en'),
            user_type='patient'
        )
        Patient.objects.create(patient_id=user)
        return user

class ProviderRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    specialty = serializers.ChoiceField(choices=['generalist', 'nurse', 'midwife', 'other'])
    other_specialty = serializers.CharField(max_length=200, required=False, allow_blank=True)
    license_number = serializers.CharField(max_length=100)
    
    class Meta:
        model = User
        fields = ('phone_number', 'email', 'password', 'full_name', 'specialty', 'other_specialty', 'license_number')

    def create(self, validated_data):
        specialty = validated_data.pop('specialty')
        other_specialty = validated_data.pop('other_specialty', '')
        license_number = validated_data.pop('license_number')
        
        user = User.objects.create_user(
            phone_number=validated_data.get('phone_number'),
            email=validated_data.get('email'),
            password=validated_data['password'],
            full_name=validated_data.get('full_name', ''),
            user_type='provider'
        )
        HealthcareProvider.objects.create(
            provider_id=user,
            specialty=specialty,
            other_specialty=other_specialty,
            license_number=license_number
        )
        return user

class OTPSendSerializer(serializers.Serializer):
    phone_number = serializers.CharField()

class OTPVerifySerializer(serializers.Serializer):
    phone_number = serializers.CharField()
    otp = serializers.CharField()

class EmailOTPSendSerializer(serializers.Serializer):
    email = serializers.EmailField()

class EmailOTPVerifySerializer(serializers.Serializer):
    email = serializers.EmailField()
    otp = serializers.CharField()

class PasswordResetConfirmSerializer(serializers.Serializer):
    phone_number = serializers.CharField()
    otp = serializers.CharField()
    new_password = serializers.CharField()

class FCMTokenSerializer(serializers.Serializer):
    fcm_token = serializers.CharField()
