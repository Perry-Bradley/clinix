import logging
from celery import shared_task
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from .models import Notification
from apps.accounts.models import User

logger = logging.getLogger(__name__)


def _send_fcm_push(fcm_token, title, body, data=None):
    """Send a push notification via Firebase Cloud Messaging.

    Uses the Clinix launcher icon (`@mipmap/ic_launcher`) on Android so the
    notification shade matches the app brand.

    Special case: when `data['type'] == 'incoming_call'` we send a DATA-ONLY
    high-priority message — no `notification` field. That guarantees the
    receiver app's FirebaseMessaging.onBackgroundMessage handler runs, which
    in turn triggers the native CallKit UI so the device wakes + rings even
    when locked. Including a `notification` field would let Android display
    a tray banner without ever calling our handler, which is the wrong UX
    for a call.
    """
    try:
        from firebase_admin import messaging

        data_dict = {k: str(v) for k, v in (data or {}).items()}
        is_call = data_dict.get('type') == 'incoming_call'

        if is_call:
            message = messaging.Message(
                data=data_dict,
                token=fcm_token,
                android=messaging.AndroidConfig(
                    priority='high',
                    # No `notification` block — keeps it data-only so the
                    # background isolate handler on the device runs.
                ),
                apns=messaging.APNSConfig(
                    headers={
                        'apns-push-type': 'voip',
                        'apns-priority': '10',
                    },
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(content_available=True),
                    ),
                ),
            )
        else:
            message = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                data=data_dict,
                token=fcm_token,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        icon='ic_launcher',
                        color='#1B4080',
                        channel_id='clinix_default',
                    ),
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(sound='default'),
                    ),
                ),
            )
        response = messaging.send(message)
        logger.info(f"FCM sent: {response}")
        return True
    except Exception as e:
        logger.warning(f"FCM send failed: {e}")
        return False


@shared_task
def send_notification(user_id, title, body, notification_type, data=None):
    """
    Create a notification record, deliver via WebSocket (in-app),
    and send a push notification via FCM if the user has a token.
    """
    try:
        user = User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        return

    # Create notification in DB
    notification = Notification.objects.create(
        user=user,
        title=title,
        body=body,
        type=notification_type,
        channel='push',
        data=data,
    )

    # Send via WebSocket (in-app real-time)
    try:
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f'notify_{user.user_id}',
            {
                'type': 'notify_message',
                'notification': {
                    'notification_id': str(notification.notification_id),
                    'title': notification.title,
                    'body': notification.body,
                    'type': notification.type,
                    'data': notification.data,
                    'sent_at': notification.sent_at.isoformat(),
                }
            }
        )
    except Exception as e:
        logger.warning(f"WebSocket send failed: {e}")

    # Send via FCM push notification
    if user.fcm_token:
        _send_fcm_push(
            fcm_token=user.fcm_token,
            title=title,
            body=body,
            data=data,
        )
