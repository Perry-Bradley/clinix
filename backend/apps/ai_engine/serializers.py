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
    # Blank allowed so a patient can send a photo without a caption.
    message = serializers.CharField(required=False, allow_blank=True, default='')
    image = serializers.CharField(required=False, allow_blank=True, help_text="Base64 encoded image string")

    def validate(self, attrs):
        if not (attrs.get('message') or '').strip() and not (attrs.get('image') or '').strip():
            raise serializers.ValidationError('Provide a message or an image.')
        return attrs
