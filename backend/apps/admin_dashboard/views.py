from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Sum, Count
from django.utils import timezone
from .permissions import IsSuperAdminUser
from apps.accounts.models import User
from apps.patients.models import Patient
from apps.providers.models import HealthcareProvider, ProviderCredential
from apps.appointments.models import Appointment
from apps.consultations.models import Consultation
from apps.payments.models import Payment
from apps.accounts.serializers import UserSerializer
from apps.providers.serializers import ProviderCredentialSerializer
from apps.appointments.serializers import AppointmentDetailSerializer
import csv
from django.http import HttpResponse

class PlatformDashboardView(APIView):
    permission_classes = [IsSuperAdminUser]

    def get(self, request):
        total_patients = Patient.objects.count()
        total_providers = HealthcareProvider.objects.filter(verification_status='approved').count()
        pending_providers = HealthcareProvider.objects.filter(verification_status='pending').count()
        total_consultations = Consultation.objects.count()
        revenue = Payment.objects.filter(status='success').aggregate(Sum('platform_fee'))['platform_fee__sum'] or 0.00
        
        return Response({
            'total_patients': total_patients,
            'total_providers': total_providers,
            'pending_verifications': pending_providers,
            'total_consultations': total_consultations,
            'total_revenue': revenue
        })

class UserListView(generics.ListAPIView):
    serializer_class = UserSerializer
    permission_classes = [IsSuperAdminUser]
    queryset = User.objects.all().order_by('-created_at')

class UserDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [IsSuperAdminUser]
    queryset = User.objects.all()

class VerificationListView(generics.ListAPIView):
    # Returning providers with pending status and their nested credentials
    permission_classes = [IsSuperAdminUser]
    
    def get(self, request):
        providers = HealthcareProvider.objects.filter(verification_status='pending')
        # simple manual serialization for dashboard
        data = []
        for p in providers:
            data.append({
                'provider_id': p.provider_id.user_id,
                'name': f"{p.provider_id.first_name} {p.provider_id.last_name}",
                'specialization': p.specialization,
                'license_number': p.license_number,
                'submitted_at': p.provider_id.created_at
            })
        return Response(data)

class VerificationDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsSuperAdminUser]
    
    def get(self, request, pk):
        provider = HealthcareProvider.objects.get(provider_id=pk)
        credentials = ProviderCredential.objects.filter(provider=provider)
        cd_data = ProviderCredentialSerializer(credentials, many=True).data
        return Response({
            'provider_id': provider.provider_id.user_id,
            'specialization': provider.specialization,
            'license_number': provider.license_number,
            'documents': cd_data
        })
        
    def patch(self, request, pk):
        provider = HealthcareProvider.objects.get(provider_id=pk)
        status_val = request.data.get('status') # 'approved' or 'rejected'
        notes = request.data.get('notes', '')
        
        if status_val in ['approved', 'rejected']:
            provider.verification_status = status_val
            provider.verification_notes = notes
            provider.verified_at = timezone.now()
            provider.verified_by = request.user
            provider.save()
            return Response({'status': f'Provider {status_val}'})
        return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)

class PlatformAppointmentsView(generics.ListAPIView):
    serializer_class = AppointmentDetailSerializer
    permission_classes = [IsSuperAdminUser]
    queryset = Appointment.objects.all().order_by('-created_at')

class AnalyticsRevenueView(APIView):
    permission_classes = [IsSuperAdminUser]
    
    def get(self, request):
        # Mocking daily revenue for chart
        return Response({'data': [{'date': '2025-01-01', 'revenue': 5000}]})
        
class AnalyticsConsultationView(APIView):
    permission_classes = [IsSuperAdminUser]
    
    def get(self, request):
        # Mocking daily consultations for chart
        return Response({'data': [{'date': '2025-01-01', 'consultations': 25}]})

class ExportCSVReportView(APIView):
    permission_classes = [IsSuperAdminUser]
    
    def get(self, request):
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="clinix_report.csv"'
        
        writer = csv.writer(response)
        writer.writerow(['ID', 'Status', 'Date'])
        writer.writerow(['1', 'Confirmed', '2025-01-01'])
        return response
