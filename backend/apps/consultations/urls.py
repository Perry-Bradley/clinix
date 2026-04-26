from django.urls import path
from .views import (
    ConsultationStartView, ConsultationDetailView, ConsultationEndView,
    ConsultationPrescriptionView, DoctorPrescriptionCreateView, PrescriptionShareView,
    ConsultationTranscriptView, ConsultationAudioUploadView,
    ConsultationRingView, ConsultationMissedCallView, CallHistoryView,
    WebRTCSignalEndpointView,
    AgoraTokenView, ChatFileUploadView, ChatMessageListView,
    PatientRemindersView, ReminderLogView, ReminderAdherenceView,
    MedicalRecordListCreateView, MedicalRecordDetailView, MedicalRecordShareView,
    ReferralListCreateView, ReferralDetailView,
)

urlpatterns = [
    path('start/', ConsultationStartView.as_view(), name='consultation_start'),
    path('<uuid:pk>/', ConsultationDetailView.as_view(), name='consultation_detail'),
    path('<uuid:pk>/end/', ConsultationEndView.as_view(), name='consultation_end'),
    path('<uuid:pk>/prescription/', ConsultationPrescriptionView.as_view(), name='consultation_prescription'),
    path('prescriptions/', DoctorPrescriptionCreateView.as_view(), name='doctor_prescription_create'),
    path('prescriptions/<uuid:prescription_id>/share/', PrescriptionShareView.as_view(), name='prescription_share'),
    path('<uuid:pk>/transcript/', ConsultationTranscriptView.as_view(), name='consultation_transcript'),
    path('<uuid:pk>/audio/', ConsultationAudioUploadView.as_view(), name='consultation_audio_upload'),
    path('<uuid:pk>/ring/', ConsultationRingView.as_view(), name='consultation_ring'),
    path('<uuid:pk>/ring/missed/', ConsultationMissedCallView.as_view(), name='consultation_ring_missed'),
    path('calls/', CallHistoryView.as_view(), name='call_history'),
    path('webrtc/signal/', WebRTCSignalEndpointView.as_view(), name='webrtc_signal'),
    path('agora/token/', AgoraTokenView.as_view(), name='agora_token'),
    path('<uuid:pk>/upload/', ChatFileUploadView.as_view(), name='chat_file_upload'),
    path('<uuid:pk>/messages/', ChatMessageListView.as_view(), name='chat_message_list'),
    path('reminders/', PatientRemindersView.as_view(), name='patient_reminders'),
    path('reminders/<uuid:reminder_id>/log/', ReminderLogView.as_view(), name='reminder_log'),
    path('reminders/adherence/', ReminderAdherenceView.as_view(), name='reminder_adherence'),
    # Medical records
    path('records/', MedicalRecordListCreateView.as_view(), name='medical_records'),
    path('records/<uuid:record_id>/', MedicalRecordDetailView.as_view(), name='medical_record_detail'),
    path('records/<uuid:record_id>/share/', MedicalRecordShareView.as_view(), name='medical_record_share'),
    # Referrals
    path('referrals/', ReferralListCreateView.as_view(), name='referrals'),
    path('referrals/<uuid:referral_id>/', ReferralDetailView.as_view(), name='referral_detail'),
]
