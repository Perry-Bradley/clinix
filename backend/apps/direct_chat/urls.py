from django.urls import path
from .views import (
    ConversationListView, ConversationStartView, ConversationStartWithProviderView,
    MessageListView,
)

urlpatterns = [
    path('conversations/', ConversationListView.as_view(), name='dchat_conversations'),
    path('start/', ConversationStartView.as_view(), name='dchat_start'),
    path('start/<uuid:provider_id>/', ConversationStartWithProviderView.as_view(), name='dchat_start_with_provider'),
    path('<uuid:conversation_id>/messages/', MessageListView.as_view(), name='dchat_messages'),
]
