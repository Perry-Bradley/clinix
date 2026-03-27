from rest_framework import serializers
from .models import Appointment
from apps.patients.serializers import PatientProfileSerializer
from apps.providers.serializers import ProviderPublicSerializer

class AppointmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Appointment
        fields = '__all__'
        read_only_fields = ('appointment_id', 'patient', 'status', 'created_at')

class AppointmentDetailSerializer(serializers.ModelSerializer):
    patient = PatientProfileSerializer(read_only=True)
    provider = ProviderPublicSerializer(read_only=True)
    
    class Meta:
        model = Appointment
        fields = '__all__'
        read_only_fields = ('appointment_id', 'patient', 'provider', 'status', 'created_at')
