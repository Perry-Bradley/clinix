from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from django.db.models import Count
from django.utils import timezone
from .models import Patient
from .serializers import PatientProfileSerializer
from apps.consultations.models import MedicalRecord, Prescription
from apps.consultations.serializers import MedicalRecordSerializer, PrescriptionSerializer
from apps.appointments.models import Appointment

class PatientProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = PatientProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        patient, _ = Patient.objects.get_or_create(patient_id=self.request.user)
        return patient

class PatientMedicalRecordsView(generics.ListAPIView):
    serializer_class = MedicalRecordSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return MedicalRecord.objects.filter(patient__patient_id=self.request.user).order_dict('-created_at')

class PatientMedicalRecordDetailView(generics.RetrieveAPIView):
    serializer_class = MedicalRecordSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return MedicalRecord.objects.filter(patient__patient_id=self.request.user)

class PatientPrescriptionsView(generics.ListAPIView):
    serializer_class = PrescriptionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Prescription.objects.filter(patient__patient_id=self.request.user).order_by('-issued_at')

class PatientDashboardView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        upcoming_appointments_count = Appointment.objects.filter(
            patient__patient_id=user,
            status='confirmed',
            scheduled_at__gte=timezone.now()
        ).count()
        recent_records = MedicalRecord.objects.filter(patient__patient_id=user).count()
        
        return Response({
            'upcoming_appointments': upcoming_appointments_count,
            'total_medical_records': recent_records,
            'user_name': user.first_name,
        })
