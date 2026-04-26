from django.urls import path
from .views import (
    ProviderProfileView, ProviderCredentialsView, ProviderScheduleView,
    ProviderEarningsView, ProviderDashboardView, ProviderNearbyView,
    ProviderPublicDetailView, ProviderWithdrawalView, ProviderReviewListCreateView,
    SpecialtyListView, ProviderRecommendedView,
)

urlpatterns = [
    path('profile/', ProviderProfileView.as_view(), name='provider_profile'),
    path('credentials/', ProviderCredentialsView.as_view(), name='provider_credentials'),
    path('schedule/', ProviderScheduleView.as_view(), name='provider_schedule'),
    path('earnings/', ProviderEarningsView.as_view(), name='provider_earnings'),
    path('dashboard/', ProviderDashboardView.as_view(), name='provider_dashboard'),
    path('nearby/', ProviderNearbyView.as_view(), name='provider_nearby'),
    path('nearby', ProviderNearbyView.as_view()),
    path('recommended/', ProviderRecommendedView.as_view(), name='provider_recommended'),
    path('specialties/', SpecialtyListView.as_view(), name='provider_specialties'),
    path('withdraw/', ProviderWithdrawalView.as_view(), name='provider_withdrawal'),
    path('<uuid:pk>/', ProviderPublicDetailView.as_view(), name='provider_detail'),
    path('<uuid:pk>/reviews/', ProviderReviewListCreateView.as_view(), name='provider_reviews'),
    path('', ProviderNearbyView.as_view(), name='provider_list'),
]
