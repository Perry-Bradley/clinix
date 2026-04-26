from rest_framework import serializers
from .models import Conversation, DirectMessage


class DirectMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source='sender.full_name', read_only=True)
    sender_id = serializers.UUIDField(source='sender.user_id', read_only=True)

    class Meta:
        model = DirectMessage
        fields = (
            'message_id', 'conversation', 'sender_id', 'sender_name',
            'content', 'message_type', 'file_url', 'file_name',
            'metadata', 'is_read', 'created_at',
        )
        read_only_fields = ('message_id', 'sender_id', 'sender_name', 'is_read', 'created_at')


class ConversationSerializer(serializers.ModelSerializer):
    peer_id = serializers.SerializerMethodField()
    peer_name = serializers.SerializerMethodField()
    peer_photo = serializers.SerializerMethodField()
    peer_user_type = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = (
            'conversation_id', 'peer_id', 'peer_name', 'peer_photo', 'peer_user_type',
            'last_message', 'last_message_at', 'unread_count', 'created_at',
        )

    def _peer(self, obj):
        user = self.context.get('request').user if self.context.get('request') else None
        if not user:
            return obj.user_b
        return obj.other_participant(user)

    def get_peer_id(self, obj):
        return str(self._peer(obj).user_id)

    def get_peer_name(self, obj):
        return self._peer(obj).full_name or 'User'

    def get_peer_photo(self, obj):
        return self._peer(obj).profile_photo

    def get_peer_user_type(self, obj):
        return self._peer(obj).user_type

    def get_last_message(self, obj):
        msg = obj.messages.order_by('-created_at').first()
        if not msg:
            return None
        return {
            'content': msg.content,
            'message_type': msg.message_type,
            'sender_id': str(msg.sender.user_id),
            'created_at': msg.created_at.isoformat(),
        }

    def get_unread_count(self, obj):
        user = self.context.get('request').user if self.context.get('request') else None
        if not user:
            return 0
        return obj.messages.filter(is_read=False).exclude(sender=user).count()
