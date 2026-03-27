from django.urls import path
from .views import AppointmentListCreateView, AppointmentDetailView, AvailableSlotsView

urlpatterns = [
    path('', AppointmentListCreateView.as_view(), name='appointment_list_create'),
    path('available-slots/', AvailableSlotsView.as_view(), name='available_slots'),
    path('<uuid:pk>/', AppointmentDetailView.as_view(), name='appointment_detail'),
]
