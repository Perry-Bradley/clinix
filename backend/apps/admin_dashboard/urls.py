from django.urls import path
from .views import (
    PlatformDashboardView, UserListView, UserDetailView, VerificationListView,
    VerificationDetailView, PlatformAppointmentsView, AnalyticsRevenueView,
    AnalyticsConsultationView, ExportCSVReportView,
    AdminPatientListView, AdminPatientDetailView,
    AdminWithdrawalListView, AdminWithdrawalActionView, AdminRevenueStatsView,
    AdminSpecialtyListCreateView, AdminSpecialtyDetailView,
)

urlpatterns = [
    path('dashboard/', PlatformDashboardView.as_view(), name='admin_dashboard'),
    path('users/', UserListView.as_view(), name='admin_users'),
    path('users/<uuid:pk>/', UserDetailView.as_view(), name='admin_user_detail'),
    path('specialties/', AdminSpecialtyListCreateView.as_view(), name='admin_specialties'),
    path('specialties/<uuid:specialty_id>/', AdminSpecialtyDetailView.as_view(), name='admin_specialty_detail'),
    path('verifications/', VerificationListView.as_view(), name='admin_verifications'),
    path('verifications/<uuid:pk>/', VerificationDetailView.as_view(), name='admin_verification_detail'),
    path('patients/', AdminPatientListView.as_view(), name='admin_patients'),
    path('patients/<uuid:pk>/', AdminPatientDetailView.as_view(), name='admin_patient_detail'),
    path('appointments/', PlatformAppointmentsView.as_view(), name='admin_appointments'),
    path('analytics/revenue/', AnalyticsRevenueView.as_view(), name='admin_revenue'),
    path('analytics/consultations/', AnalyticsConsultationView.as_view(), name='admin_analytics_consultations'),
    path('reports/export/', ExportCSVReportView.as_view(), name='admin_export'),
    path('withdrawals/', AdminWithdrawalListView.as_view(), name='admin_withdrawals'),
    path('withdrawals/<int:pk>/action/', AdminWithdrawalActionView.as_view(), name='admin_withdrawal_action'),
    path('revenue-stats/', AdminRevenueStatsView.as_view(), name='revenue_stats'),
]
