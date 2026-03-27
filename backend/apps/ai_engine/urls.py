from django.urls import path
from .views import SymptomCheckView, AISessionDetailView

urlpatterns = [
    path('symptom-check/', SymptomCheckView.as_view(), name='symptom_check'),
    path('session/<uuid:pk>/', AISessionDetailView.as_view(), name='ai_session_detail'),
]
