from django.urls import path
from .views import (
    ConsultationStartView, ConsultationDetailView, ConsultationEndView,
    ConsultationPrescriptionView, ConsultationTranscriptView, WebRTCSignalEndpointView
)

urlpatterns = [
    path('start/', ConsultationStartView.as_view(), name='consultation_start'),
    path('<uuid:pk>/', ConsultationDetailView.as_view(), name='consultation_detail'),
    path('<uuid:pk>/end/', ConsultationEndView.as_view(), name='consultation_end'),
    path('<uuid:pk>/prescription/', ConsultationPrescriptionView.as_view(), name='consultation_prescription'),
    path('<uuid:pk>/transcript/', ConsultationTranscriptView.as_view(), name='consultation_transcript'),
    path('webrtc/signal/', WebRTCSignalEndpointView.as_view(), name='webrtc_signal'),
]
