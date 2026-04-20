from django.urls import path
from .views import (
    ConsultationStartView, ConsultationDetailView, ConsultationEndView,
    ConsultationPrescriptionView, ConsultationTranscriptView, WebRTCSignalEndpointView,
    AgoraTokenView, ChatFileUploadView, ChatMessageListView,
    PatientRemindersView, ReminderLogView, ReminderAdherenceView,
)

urlpatterns = [
    path('start/', ConsultationStartView.as_view(), name='consultation_start'),
    path('<uuid:pk>/', ConsultationDetailView.as_view(), name='consultation_detail'),
    path('<uuid:pk>/end/', ConsultationEndView.as_view(), name='consultation_end'),
    path('<uuid:pk>/prescription/', ConsultationPrescriptionView.as_view(), name='consultation_prescription'),
    path('<uuid:pk>/transcript/', ConsultationTranscriptView.as_view(), name='consultation_transcript'),
    path('webrtc/signal/', WebRTCSignalEndpointView.as_view(), name='webrtc_signal'),
    path('agora/token/', AgoraTokenView.as_view(), name='agora_token'),
    path('<uuid:pk>/upload/', ChatFileUploadView.as_view(), name='chat_file_upload'),
    path('<uuid:pk>/messages/', ChatMessageListView.as_view(), name='chat_message_list'),
    path('reminders/', PatientRemindersView.as_view(), name='patient_reminders'),
    path('reminders/<uuid:reminder_id>/log/', ReminderLogView.as_view(), name='reminder_log'),
    path('reminders/adherence/', ReminderAdherenceView.as_view(), name='reminder_adherence'),
]
