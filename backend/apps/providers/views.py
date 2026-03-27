from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Sum, Count
from django.utils import timezone
from .models import HealthcareProvider, ProviderCredential
from .serializers import ProviderProfileSerializer, ProviderCredentialSerializer, ProviderPublicSerializer
from apps.appointments.models import Appointment
from apps.payments.models import Payment
from apps.locations.models import Location
import math

class ProviderProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = ProviderProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        provider, _ = HealthcareProvider.objects.get_or_create(provider_id=self.request.user)
        return provider

class ProviderCredentialsView(generics.ListCreateAPIView):
    serializer_class = ProviderCredentialSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return ProviderCredential.objects.filter(provider__provider_id=self.request.user)
        
    def perform_create(self, serializer):
        provider = HealthcareProvider.objects.get(provider_id=self.request.user)
        serializer.save(provider=provider)

class ProviderScheduleView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        provider = HealthcareProvider.objects.get(provider_id=request.user)
        return Response({'is_available': provider.is_available})
        
    def post(self, request):
        provider = HealthcareProvider.objects.get(provider_id=request.user)
        is_available = request.data.get('is_available', True)
        provider.is_available = is_available
        provider.save()
        return Response({'is_available': provider.is_available})

class ProviderEarningsView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        provider = HealthcareProvider.objects.get(provider_id=request.user)
        total_payout = Payment.objects.filter(
            provider=provider, status='success'
        ).aggregate(Sum('provider_payout'))['provider_payout__sum'] or 0.00
        
        return Response({
            'total_earnings': total_payout,
            'currency': 'XAF'
        })

class ProviderDashboardView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        provider = HealthcareProvider.objects.get(provider_id=request.user)
        today = timezone.localtime().date()
        
        today_appointments = Appointment.objects.filter(
            provider=provider,
            scheduled_at__date=today
        ).count()
        
        pending_requests = Appointment.objects.filter(
            provider=provider,
            status='pending'
        ).count()
        
        return Response({
            'today_appointments': today_appointments,
            'pending_requests': pending_requests,
            'is_available': provider.is_available,
            'rating': provider.rating,
            'total_consultations': provider.total_consultations
        })

class ProviderNearbyView(generics.ListAPIView):
    serializer_class = ProviderPublicSerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        queryset = HealthcareProvider.objects.filter(verification_status='approved')
        specialization = self.request.query_params.get('specialization')
        is_available = self.request.query_params.get('available')
        
        if specialization:
            queryset = queryset.filter(specialization__icontains=specialization)
        if is_available == 'true':
            queryset = queryset.filter(is_available=True)
            
        lat = self.request.query_params.get('lat')
        lng = self.request.query_params.get('lng')
        radius = self.request.query_params.get('radius')
        
        if lat and lng and radius:
            try:
                lat = float(lat)
                lng = float(lng)
                radius = float(radius)
                
                # Simple bounding box filter for locations
                lat_diff = radius / 111.0 # approx degrees per km
                lng_diff = radius / (111.0 * math.cos(math.radians(lat)))
                
                locations = Location.objects.filter(
                    latitude__range=(lat - lat_diff, lat + lat_diff),
                    longitude__range=(lng - lng_diff, lng + lng_diff)
                )
                provider_ids = locations.values_list('provider_id', flat=True)
                queryset = queryset.filter(provider_id__in=provider_ids)
            except ValueError:
                pass
                
        return queryset

class ProviderPublicDetailView(generics.RetrieveAPIView):
    serializer_class = ProviderPublicSerializer
    permission_classes = [permissions.AllowAny]
    queryset = HealthcareProvider.objects.filter(verification_status='approved')
    lookup_field = 'provider_id'
