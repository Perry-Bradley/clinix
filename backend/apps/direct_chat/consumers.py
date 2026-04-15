import json
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from django.utils import timezone

from .models import Conversation, DirectMessage
from .serializers import DirectMessageSerializer


class DirectChatConsumer(AsyncJsonWebsocketConsumer):
    """WebSocket channel for a single conversation. URL: /ws/dchat/<conversation_id>/"""

    async def connect(self):
        user = self.scope.get('user')
        if not user or not user.is_authenticated:
            await self.close(code=4401)
            return

        self.conversation_id = self.scope['url_route']['kwargs']['conversation_id']
        self.group_name = f'dchat_{self.conversation_id}'

        # Verify user is a participant
        ok = await self._is_participant(user, self.conversation_id)
        if not ok:
            await self.close(code=4403)
            return

        self.user = user
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive_json(self, content, **kwargs):
        """Client sent a message — persist + broadcast."""
        text = (content.get('content') or content.get('message') or '').strip()
        msg_type = content.get('message_type', 'text')
        file_url = content.get('file_url')
        file_name = content.get('file_name')

        if not text and not file_url:
            return

        msg = await self._save_message(text, msg_type, file_url, file_name)
        payload = await self._serialize(msg)

        # Broadcast to the group (both participants' sockets)
        await self.channel_layer.group_send(
            self.group_name,
            {'type': 'chat_message', 'payload': payload},
        )

        # FCM push to the peer
        await self._notify_peer(msg)

    async def chat_message(self, event):
        await self.send_json(event['payload'])

    @database_sync_to_async
    def _is_participant(self, user, conversation_id):
        try:
            conv = Conversation.objects.get(conversation_id=conversation_id)
        except Conversation.DoesNotExist:
            return False
        return user == conv.user_a or user == conv.user_b

    @database_sync_to_async
    def _save_message(self, content, msg_type, file_url, file_name):
        conv = Conversation.objects.get(conversation_id=self.conversation_id)
        msg = DirectMessage.objects.create(
            conversation=conv,
            sender=self.user,
            content=content,
            message_type=msg_type,
            file_url=file_url,
            file_name=file_name,
        )
        conv.last_message_at = timezone.now()
        conv.save(update_fields=['last_message_at'])
        return msg

    @database_sync_to_async
    def _serialize(self, msg):
        import json
        from rest_framework.utils.encoders import JSONEncoder
        data = DirectMessageSerializer(msg).data
        # Convert UUIDs/dates to JSON-safe primitives so msgpack can serialize it
        return json.loads(json.dumps(data, cls=JSONEncoder))

    @database_sync_to_async
    def _notify_peer(self, msg):
        try:
            from apps.notifications.tasks import send_notification
            conv = msg.conversation
            peer = conv.other_participant(self.user)
            preview = msg.content[:80] if msg.content else ('📎 File' if msg.message_type == 'file' else '📷 Image')
            send_notification.delay(
                str(peer.user_id),
                self.user.full_name or 'New message',
                preview,
                'consultation',
                {'route': f'/chat-direct/{conv.conversation_id}', 'conversation_id': str(conv.conversation_id)},
            )
        except Exception:
            pass
