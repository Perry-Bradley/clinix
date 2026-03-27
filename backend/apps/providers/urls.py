from django.urls import path
from .views import (
    ProviderProfileView, ProviderCredentialsView, ProviderScheduleView,
    ProviderEarningsView, ProviderDashboardView, ProviderNearbyView,
    ProviderPublicDetailView
)

urlpatterns = [
    path('profile/', ProviderProfileView.as_view(), name='provider_profile'),
    path('credentials/', ProviderCredentialsView.as_view(), name='provider_credentials'),
    path('schedule/', ProviderScheduleView.as_view(), name='provider_schedule'),
    path('earnings/', ProviderEarningsView.as_view(), name='provider_earnings'),
    path('dashboard/', ProviderDashboardView.as_view(), name='provider_dashboard'),
    path('nearby/', ProviderNearbyView.as_view(), name='provider_nearby'),
    path('<uuid:provider_id>/public/', ProviderPublicDetailView.as_view(), name='provider_public_detail'),
]
