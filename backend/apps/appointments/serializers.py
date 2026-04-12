from rest_framework import serializers
from .models import Appointment
from apps.patients.serializers import PatientProfileSerializer
from apps.providers.serializers import ProviderPublicSerializer
from django.core.exceptions import ObjectDoesNotExist


class AppointmentSerializer(serializers.ModelSerializer):
    consultation_id = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = Appointment
        fields = '__all__'
        read_only_fields = ('appointment_id', 'patient', 'status', 'created_at')

    def get_consultation_id(self, obj):
        try:
            return str(obj.consultation.consultation_id)
        except ObjectDoesNotExist:
            return None


class AppointmentDetailSerializer(serializers.ModelSerializer):
    patient = PatientProfileSerializer(read_only=True)
    provider = ProviderPublicSerializer(read_only=True)
    consultation_id = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = Appointment
        fields = '__all__'
        read_only_fields = ('appointment_id', 'patient', 'provider', 'status', 'created_at')

    def get_consultation_id(self, obj):
        try:
            return str(obj.consultation.consultation_id)
        except ObjectDoesNotExist:
            return None
