from django.urls import path
from .views import (
    PlatformDashboardView, UserListView, UserDetailView, VerificationListView,
    VerificationDetailView, PlatformAppointmentsView, AnalyticsRevenueView,
    AnalyticsConsultationView, ExportCSVReportView
)

urlpatterns = [
    path('dashboard/', PlatformDashboardView.as_view(), name='admin_dashboard'),
    path('users/', UserListView.as_view(), name='admin_users'),
    path('users/<uuid:pk>/', UserDetailView.as_view(), name='admin_user_detail'),
    path('verifications/', VerificationListView.as_view(), name='admin_verifications'),
    path('verifications/<uuid:pk>/', VerificationDetailView.as_view(), name='admin_verification_detail'),
    path('appointments/', PlatformAppointmentsView.as_view(), name='admin_appointments'),
    path('analytics/revenue/', AnalyticsRevenueView.as_view(), name='admin_revenue'),
    path('analytics/consultations/', AnalyticsConsultationView.as_view(), name='admin_analytics_consultations'),
    path('reports/export/', ExportCSVReportView.as_view(), name='admin_export'),
]
