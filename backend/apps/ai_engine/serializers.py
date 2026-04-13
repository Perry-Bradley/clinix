from rest_framework import serializers
from .models import AISymptomSession, AIChatMessage

class AIChatMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = AIChatMessage
        fields = ['id', 'sender', 'message', 'timestamp']

class AISymptomSessionSerializer(serializers.ModelSerializer):
    messages = AIChatMessageSerializer(many=True, read_only=True)
    
    class Meta:
        model = AISymptomSession
        fields = ['session_id', 'is_active', 'messages', 'recommendation', 'suggested_specialization', 'created_at']
        read_only_fields = ('session_id', 'created_at')

class SymptomChatMessageRequestSerializer(serializers.Serializer):
    message = serializers.CharField()
    image = serializers.CharField(required=False, allow_blank=True, help_text="Base64 encoded image string")
