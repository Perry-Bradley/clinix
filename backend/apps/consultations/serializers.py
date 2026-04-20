from rest_framework import serializers
from .models import Consultation, Prescription, MedicalRecord, ChatMessage, MedicationReminder, MedicationLog
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

class MedicationReminderSerializer(serializers.ModelSerializer):
    adherence_rate = serializers.SerializerMethodField()

    class Meta:
        model = MedicationReminder
        fields = '__all__'

    def get_adherence_rate(self, obj):
        total = obj.logs.count()
        if total == 0:
            return None
        taken = obj.logs.filter(status='taken').count()
        return round((taken / total) * 100)


class MedicationLogSerializer(serializers.ModelSerializer):
    medication_name = serializers.CharField(source='reminder.medication_name', read_only=True)

    class Meta:
        model = MedicationLog
        fields = '__all__'


class ChatMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()
    sender_id = serializers.CharField(source='sender.user_id', read_only=True)

    def get_sender_name(self, obj):
        u = obj.sender
        return (u.full_name or u.email or u.phone_number or str(u.user_id)).strip()

    class Meta:
        model = ChatMessage
        fields = [
            'message_id', 'consultation', 'sender_id', 'sender_name',
            'message_type', 'content', 'file_url', 'file_name',
            'is_read', 'created_at'
        ]
