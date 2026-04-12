"""
ASGI config for clinix_project project.

It exposes the ASGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/6.0/howto/deployment/asgi/
"""

import os

from django.core.asgi import get_asgi_application

from channels.auth import AuthMiddlewareStack
from channels.routing import ProtocolTypeRouter, URLRouter
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'clinix_project.settings.development')
django_asgi_app = get_asgi_application()

import apps.consultations.routing
import apps.notifications.routing

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": AuthMiddlewareStack(
        URLRouter(
            apps.consultations.routing.websocket_urlpatterns +
            apps.notifications.routing.websocket_urlpatterns
        )
    ),
})
