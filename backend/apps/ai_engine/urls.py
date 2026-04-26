from django.urls import path
from .views import (
    AIChatSessionListView,
    AIChatStartView,
    AIChatMessageView,
    AIChatDetailView,
    AIChatCompleteView,
    AIChatRecommendView,
)

urlpatterns = [
    path('chat/sessions/', AIChatSessionListView.as_view(), name='ai_chat_sessions'),
    path('chat/start/', AIChatStartView.as_view(), name='ai_chat_start'),
    path('chat/<uuid:session_id>/message/', AIChatMessageView.as_view(), name='ai_chat_message'),
    path('chat/<uuid:session_id>/', AIChatDetailView.as_view(), name='ai_chat_detail'),
    path('chat/<uuid:session_id>/complete/', AIChatCompleteView.as_view(), name='ai_chat_complete'),
    path('chat/<uuid:session_id>/recommend/', AIChatRecommendView.as_view(), name='ai_chat_recommend'),
]
