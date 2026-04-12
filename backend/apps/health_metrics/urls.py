from django.urls import path
from .views import HeartRateReadingListCreateView, DailyActivitySyncView, HealthSummaryView

urlpatterns = [
    path('heart-rate/', HeartRateReadingListCreateView.as_view(), name='heart-rate-list'),
    path('activity/sync/', DailyActivitySyncView.as_view(), name='activity-sync'),
    path('summary/', HealthSummaryView.as_view(), name='health-summary'),
]
