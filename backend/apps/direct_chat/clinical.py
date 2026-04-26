"""Helpers for posting doctor-issued clinical messages (prescriptions,
medical records, referrals) into the patient↔doctor conversation, so the
patient sees them inline in chat in addition to the dedicated record page.
"""
from django.utils import timezone

from .models import Conversation, DirectMessage
from .serializers import DirectMessageSerializer


def post_clinical_message(*, doctor_user, patient_user, message_type, content, metadata):
    """Create a DirectMessage in the doctor↔patient conversation and broadcast
    it to the chat WebSocket group. Does NOT send an FCM push — the caller is
    expected to fire a typed `send_notification.delay()` on its own so the
    notification surfaces with the right title/icon.

    Returns the created DirectMessage.
    """
    conversation, _ = Conversation.get_or_create_between(doctor_user, patient_user)
    message = DirectMessage.objects.create(
        conversation=conversation,
        sender=doctor_user,
        content=content or '',
        message_type=message_type,
        metadata=metadata or {},
    )
    conversation.last_message_at = timezone.now()
    conversation.save(update_fields=['last_message_at'])

    # Best-effort live broadcast so a patient with the chat screen open sees it
    # appear immediately. Failure here doesn't affect the FCM/notification flow.
    try:
        from channels.layers import get_channel_layer
        from asgiref.sync import async_to_sync
        layer = get_channel_layer()
        async_to_sync(layer.group_send)(
            f'dchat_{conversation.conversation_id}',
            {
                'type': 'chat_message',
                'payload': DirectMessageSerializer(message).data,
            },
        )
    except Exception:
        pass

    return message
