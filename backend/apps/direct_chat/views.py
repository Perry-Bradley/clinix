from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone

from apps.accounts.models import User
from .models import Conversation, DirectMessage
from .serializers import ConversationSerializer, DirectMessageSerializer


class ConversationListView(generics.ListAPIView):
    """List all conversations involving the current user, most recent first."""
    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return Conversation.objects.filter(Q(user_a=user) | Q(user_b=user)).order_by('-last_message_at', '-created_at')


class ConversationStartView(APIView):
    """POST {peer_id: uuid} → returns conversation (created or existing) with that user."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        peer_id = request.data.get('peer_id')
        if not peer_id:
            return Response({'error': 'peer_id is required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            peer = User.objects.get(user_id=peer_id)
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

        if peer == request.user:
            return Response({'error': 'Cannot start a conversation with yourself'}, status=status.HTTP_400_BAD_REQUEST)

        conversation, _ = Conversation.get_or_create_between(request.user, peer)
        serializer = ConversationSerializer(conversation, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)


class ConversationStartWithProviderView(APIView):
    """Convenience: start/get conversation with a provider by their provider_id (= user_id)."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, provider_id):
        try:
            peer = User.objects.get(user_id=provider_id)
        except User.DoesNotExist:
            return Response({'error': 'Provider not found'}, status=status.HTTP_404_NOT_FOUND)
        if peer == request.user:
            return Response({'error': 'Cannot message yourself'}, status=status.HTTP_400_BAD_REQUEST)
        conversation, _ = Conversation.get_or_create_between(request.user, peer)
        return Response(ConversationSerializer(conversation, context={'request': request}).data)


class MessageListView(generics.ListCreateAPIView):
    """List messages in a conversation + POST to send a new message (HTTP fallback)."""
    serializer_class = DirectMessageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        conv = self._get_conversation()
        return DirectMessage.objects.filter(conversation=conv).order_by('created_at')

    def _get_conversation(self):
        conv_id = self.kwargs.get('conversation_id')
        conv = get_object_or_404(Conversation, conversation_id=conv_id)
        if self.request.user not in (conv.user_a, conv.user_b):
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied('You are not a participant in this conversation.')
        return conv

    def list(self, request, *args, **kwargs):
        conv = self._get_conversation()
        # Mark peer's messages as read when fetching
        DirectMessage.objects.filter(conversation=conv, is_read=False).exclude(sender=request.user).update(is_read=True)
        qs = DirectMessage.objects.filter(conversation=conv).order_by('created_at')
        return Response(DirectMessageSerializer(qs, many=True).data)

    def create(self, request, *args, **kwargs):
        conv = self._get_conversation()
        content = (request.data.get('content') or '').strip()
        message_type = request.data.get('message_type', 'text')
        file_url = request.data.get('file_url')
        file_name = request.data.get('file_name')

        if not content and not file_url:
            return Response({'error': 'Empty message'}, status=status.HTTP_400_BAD_REQUEST)

        msg = DirectMessage.objects.create(
            conversation=conv,
            sender=request.user,
            content=content,
            message_type=message_type,
            file_url=file_url,
            file_name=file_name,
        )
        conv.last_message_at = timezone.now()
        conv.save(update_fields=['last_message_at'])

        # Notify the peer via FCM + WebSocket
        peer = conv.other_participant(request.user)
        self._notify(peer, conv, msg, request.user)

        return Response(DirectMessageSerializer(msg).data, status=status.HTTP_201_CREATED)

    def _notify(self, peer, conv, msg, sender):
        # FCM push
        try:
            from apps.notifications.tasks import send_notification
            preview = msg.content[:80] if msg.content else ('📎 File' if msg.message_type == 'file' else '📷 Image')
            send_notification.delay(
                str(peer.user_id),
                sender.full_name or 'New message',
                preview,
                'consultation',
                {'route': f'/chat-direct/{conv.conversation_id}', 'conversation_id': str(conv.conversation_id)},
            )
        except Exception:
            pass
        # WebSocket broadcast
        try:
            from channels.layers import get_channel_layer
            from asgiref.sync import async_to_sync
            layer = get_channel_layer()
            async_to_sync(layer.group_send)(
                f'dchat_{conv.conversation_id}',
                {
                    'type': 'chat_message',
                    'payload': DirectMessageSerializer(msg).data,
                },
            )
        except Exception:
            pass
