from django.urls import path
from .views import AppointmentListCreateView, AppointmentDetailView, AvailableSlotsView, LabTestWorkflowView

urlpatterns = [
    path('', AppointmentListCreateView.as_view(), name='appointment_list_create'),
    path('available-slots/', AvailableSlotsView.as_view(), name='available_slots'),
    path('lab-tests/', LabTestWorkflowView.as_view(), name='lab_test_workflow_list'),
    path('lab-tests/<uuid:pk>/', LabTestWorkflowView.as_view(), name='lab_test_workflow_detail'),
    path('<uuid:pk>/', AppointmentDetailView.as_view(), name='appointment_detail'),
]
