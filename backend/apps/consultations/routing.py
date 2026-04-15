from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r'consultation/(?P<consultation_id>[0-9a-f-]+)/chat/$', consumers.ConsultationChatConsumer.as_asgi()),
    re_path(r'consultation/(?P<consultation_id>[0-9a-f-]+)/signal/$', consumers.WebRTCSignalingConsumer.as_asgi()),
]
