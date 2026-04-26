from rest_framework import serializers
from .models import Consultation, Prescription, MedicalRecord, ChatMessage, MedicationReminder, MedicationLog, Referral
from apps.providers.models import HealthcareProvider

class PrescriptionSerializer(serializers.ModelSerializer):
    provider_name = serializers.CharField(source='provider.provider_id.first_name', read_only=True)
    shared_with_ids = serializers.PrimaryKeyRelatedField(
        many=True, read_only=True, source='shared_with',
    )

    class Meta:
        model = Prescription
        fields = '__all__'
        read_only_fields = ('shared_with',)

class MedicalRecordSerializer(serializers.ModelSerializer):
    authored_by_name = serializers.CharField(source='authored_by.provider_id.full_name', read_only=True)
    authored_by_specialty = serializers.SerializerMethodField()
    patient_name = serializers.CharField(source='patient.patient_id.full_name', read_only=True)
    shared_with_ids = serializers.PrimaryKeyRelatedField(
        many=True, read_only=True, source='shared_with',
    )

    def get_authored_by_specialty(self, obj):
        if not obj.authored_by:
            return None
        if obj.authored_by.specialty_obj:
            return obj.authored_by.specialty_obj.name
        return obj.authored_by.other_specialty or obj.authored_by.specialty

    class Meta:
        model = MedicalRecord
        fields = '__all__'
        read_only_fields = ('record_id', 'created_at', 'updated_at', 'shared_with')


class MedicalRecordShareSerializer(serializers.Serializer):
    """Patient-controlled grant: share record X with provider Y."""
    provider_id = serializers.UUIDField()
    revoke = serializers.BooleanField(default=False, required=False)


class ReferralSerializer(serializers.ModelSerializer):
    referred_by_name = serializers.CharField(source='referred_by.provider_id.full_name', read_only=True)
    referred_to_name = serializers.CharField(source='referred_to.provider_id.full_name', read_only=True)
    referred_to_specialty = serializers.CharField(source='referred_to.specialty_obj.name', read_only=True)
    patient_name = serializers.CharField(source='patient.patient_id.full_name', read_only=True)

    class Meta:
        model = Referral
        fields = '__all__'
        read_only_fields = ('referral_id', 'referred_by', 'created_at', 'updated_at')

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
