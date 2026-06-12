"""Resilient notification dispatch.

Every push used to go through `send_notification.delay(...)`, which only
works when a Celery worker is consuming the queue. On deployments where
the worker/broker isn't running, calls never rang and pushes silently
vanished. `notify()` sends inline (on a short-lived thread, so request
latency isn't affected) unless USE_CELERY=1 is set in the environment.
"""
import logging
import os
import threading

logger = logging.getLogger(__name__)


def _use_celery() -> bool:
    return os.environ.get('USE_CELERY', '').strip().lower() in ('1', 'true', 'yes')


def notify(user_id, title, body, notification_type, data=None):
    """Fire-and-forget a notification (DB row + WebSocket + FCM)."""
    from .tasks import send_notification

    user_id = str(user_id)
    if _use_celery():
        try:
            send_notification.delay(user_id, title, body, notification_type, data)
            return
        except Exception:
            logger.warning('Celery enqueue failed — sending notification inline.')

    def _run():
        from django.db import close_old_connections
        try:
            close_old_connections()
            # A @shared_task is directly callable: runs synchronously here.
            send_notification(user_id, title, body, notification_type, data)
        except Exception:
            logger.exception('Inline notification send failed')
        finally:
            close_old_connections()

    threading.Thread(target=_run, daemon=True).start()
