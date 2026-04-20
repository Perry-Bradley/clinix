from rest_framework import generics, permissions
from .models import LabTest
from .serializers import LabTestSerializer
from apps.admin_dashboard.permissions import IsSuperAdminUser


class LabTestPublicListView(generics.ListAPIView):
    """Public endpoint — mobile app fetches available tests."""
    serializer_class = LabTestSerializer
    authentication_classes = []
    permission_classes = [permissions.AllowAny]
    queryset = LabTest.objects.filter(is_active=True)


class AdminLabTestListCreateView(generics.ListCreateAPIView):
    """Admin CRUD — list all + create new tests."""
    serializer_class = LabTestSerializer
    permission_classes = [IsSuperAdminUser]
    queryset = LabTest.objects.all()


class AdminLabTestDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Admin CRUD — get/update/delete a single test."""
    serializer_class = LabTestSerializer
    permission_classes = [IsSuperAdminUser]
    queryset = LabTest.objects.all()
