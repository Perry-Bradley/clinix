from django.urls import re_path
from .consumers import DirectChatConsumer

websocket_urlpatterns = [
    re_path(r'dchat/(?P<conversation_id>[0-9a-f-]{36})/$', DirectChatConsumer.as_asgi()),
]
