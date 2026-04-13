from django.urls import path
from .views import (
    ProviderProfileView, ProviderCredentialsView, ProviderScheduleView,
    ProviderEarningsView, ProviderDashboardView, ProviderNearbyView,
    ProviderPublicDetailView, ProviderWithdrawalView, ProviderReviewListCreateView
)

urlpatterns = [
    path('profile/', ProviderProfileView.as_view(), name='provider_profile'),
    path('credentials/', ProviderCredentialsView.as_view(), name='provider_credentials'),
    path('schedule/', ProviderScheduleView.as_view(), name='provider_schedule'),
    path('earnings/', ProviderEarningsView.as_view(), name='provider_earnings'),
    path('dashboard/', ProviderDashboardView.as_view(), name='provider_dashboard'),
    path('nearby/', ProviderNearbyView.as_view(), name='provider_nearby'),
    path('<uuid:provider_id>/public/', ProviderPublicDetailView.as_view(), name='provider_public_detail'),
    path('<uuid:provider_id>/reviews/', ProviderReviewListCreateView.as_view(), name='provider_reviews'),
    path('withdraw/', ProviderWithdrawalView.as_view(), name='provider_withdrawal'),
]
