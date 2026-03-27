from rest_framework import serializers
from .models import Consultation, Prescription, MedicalRecord
from apps.providers.models import HealthcareProvider

class PrescriptionSerializer(serializers.ModelSerializer):
    provider_name = serializers.CharField(source='provider.provider_id.first_name', read_only=True)
    
    class Meta:
        model = Prescription
        fields = '__all__'

class MedicalRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = MedicalRecord
        fields = '__all__'

class ConsultationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Consultation
        fields = '__all__'

class ConsultationStartSerializer(serializers.Serializer):
    appointment_id = serializers.UUIDField()

class ConsultationEndSerializer(serializers.Serializer):
    provider_notes = serializers.CharField(required=False, allow_blank=True)
    diagnosis = serializers.CharField(required=False, allow_blank=True)

class WebRTCSignalSerializer(serializers.Serializer):
    consultation_id = serializers.UUIDField()
    signal_data = serializers.JSONField()
