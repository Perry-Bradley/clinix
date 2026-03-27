from django.urls import path
from .views import (
    PatientProfileView, PatientMedicalRecordsView, 
    PatientMedicalRecordDetailView, PatientPrescriptionsView, PatientDashboardView
)

urlpatterns = [
    path('profile/', PatientProfileView.as_view(), name='patient_profile'),
    path('medical-records/', PatientMedicalRecordsView.as_view(), name='patient_records'),
    path('medical-records/<uuid:pk>/', PatientMedicalRecordDetailView.as_view(), name='patient_record_detail'),
    path('prescriptions/', PatientPrescriptionsView.as_view(), name='patient_prescriptions'),
    path('dashboard/', PatientDashboardView.as_view(), name='patient_dashboard'),
]
