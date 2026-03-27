from celery import shared_task
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from .models import Notification
from apps.accounts.models import User

@shared_task
def send_notification(user_id, title, message, notification_type):
    try:
        user = User.objects.get(user_id=user_id)
        # Create notification in DB
        notification = Notification.objects.create(
            user=user,
            title=title,
            message=message,
            notification_type=notification_type
        )
        
        # Send via WebSocket
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f'notify_{user.user_id}',
            {
                'type': 'notify_message',
                'notification': {
                    'notification_id': str(notification.notification_id),
                    'title': notification.title,
                    'message': notification.message,
                    'type': notification.notification_type,
                    'sent_at': notification.sent_at.isoformat()
                }
            }
        )
    except User.DoesNotExist:
        pass
