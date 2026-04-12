import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from .models import Consultation, ChatMessage
from django.contrib.auth import get_user_model

User = get_user_model()

class ConsultationChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.consultation_id = self.scope['url_route']['kwargs']['consultation_id']
        self.room_group_name = f'chat_{self.consultation_id}'

        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        await self.accept()

    async def disconnect(self, close_code):
        # Leave room group
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )

    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message = text_data_json.get('message', '')
        message_type = text_data_json.get('message_type', 'text')
        file_url = text_data_json.get('file_url', None)
        file_name = text_data_json.get('file_name', None)
        
        user = self.scope['user']
        if not user.is_authenticated:
            return

        # Save message to DB
        await self.save_message(
            consultation_id=self.consultation_id,
            user=user,
            content=message,
            message_type=message_type,
            file_url=file_url,
            file_name=file_name
        )

        # Send message to room group
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'chat_message',
                'message': message,
                'message_type': message_type,
                'file_url': file_url,
                'file_name': file_name,
                'sender_id': str(user.id),
                'sender_name': (user.full_name or user.email or user.phone_number or str(user.user_id)).strip()
            }
        )

    async def chat_message(self, event):
        # Send message to WebSocket
        await self.send(text_data=json.dumps({
            'message': event['message'],
            'message_type': event['message_type'],
            'file_url': event['file_url'],
            'file_name': event['file_name'],
            'sender_id': event['sender_id'],
            'sender_name': event['sender_name']
        }))

    @database_sync_to_async
    def save_message(self, consultation_id, user, content, message_type, file_url, file_name):
        consultation = Consultation.objects.get(pk=consultation_id)
        return ChatMessage.objects.create(
            consultation=consultation,
            sender=user,
            content=content,
            message_type=message_type,
            file_url=file_url,
            file_name=file_name
        )

class WebRTCSignalingConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.consultation_id = self.scope['url_route']['kwargs']['consultation_id']
        self.room_group_name = f'signal_{self.consultation_id}'

        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.room_group_name, self.channel_name)

    async def receive(self, text_data):
        data = json.loads(text_data)
        
        # Broadcast signal to others in room
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'webrtc_signal',
                'data': data,
                'sender_channel_name': self.channel_name
            }
        )

    async def webrtc_signal(self, event):
        # Don't send the signal back to the sender
        if self.channel_name != event.get('sender_channel_name'):
            await self.send(text_data=json.dumps(event['data']))
