from rest_framework import serializers
from .models import AISymptomSession

class AISymptomSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = AISymptomSession
        fields = '__all__'
        read_only_fields = ('session_id', 'patient', 'created_at')

class SymptomCheckRequestSerializer(serializers.Serializer):
    symptoms = serializers.CharField()
    duration = serializers.CharField()
    severity = serializers.IntegerField(min_value=1, max_value=10)
    patient_age = serializers.IntegerField()
    gender = serializers.CharField()
