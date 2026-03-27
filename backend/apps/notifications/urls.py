from django.urls import path
from .views import (
    NotificationListView, NotificationReadView, NotificationReadAllView,
    NotificationDeleteView, NotificationPreferencesView
)

urlpatterns = [
    path('', NotificationListView.as_view(), name='notification_list'),
    path('<uuid:pk>/read/', NotificationReadView.as_view(), name='notification_read'),
    path('read-all/', NotificationReadAllView.as_view(), name='notification_read_all'),
    path('<uuid:pk>/', NotificationDeleteView.as_view(), name='notification_delete'),
    path('preferences/', NotificationPreferencesView.as_view(), name='notification_preferences'),
]
