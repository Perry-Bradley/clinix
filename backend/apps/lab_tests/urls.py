from django.urls import path
from .views import LabTestPublicListView, AdminLabTestListCreateView, AdminLabTestDetailView

urlpatterns = [
    path('', LabTestPublicListView.as_view(), name='lab_tests_public'),
    path('admin/', AdminLabTestListCreateView.as_view(), name='lab_tests_admin_list'),
    path('admin/<uuid:pk>/', AdminLabTestDetailView.as_view(), name='lab_tests_admin_detail'),
]
