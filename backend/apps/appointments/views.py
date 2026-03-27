from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Q
from datetime import datetime, timedelta
from .models import Appointment
from .serializers import AppointmentSerializer, AppointmentDetailSerializer
from apps.patients.models import Patient
from apps.providers.models import HealthcareProvider

class AppointmentListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'GET':
            return AppointmentDetailSerializer
        return AppointmentSerializer

    def get_queryset(self):
        user = self.request.user
        if user.user_type == 'patient':
            return Appointment.objects.filter(patient__patient_id=user).order_by('-scheduled_at')
        elif user.user_type == 'provider':
            return Appointment.objects.filter(provider__provider_id=user).order_by('-scheduled_at')
        return Appointment.objects.none()

    def perform_create(self, serializer):
        patient = Patient.objects.get(patient_id=self.request.user)
        serializer.save(patient=patient, status='pending')

class AppointmentDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = AppointmentDetailSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.user_type == 'patient':
            return Appointment.objects.filter(patient__patient_id=user)
        elif user.user_type == 'provider':
            return Appointment.objects.filter(provider__provider_id=user)
        return Appointment.objects.none()

    def perform_destroy(self, instance):
        instance.status = 'cancelled'
        instance.cancellation_reason = self.request.data.get('cancellation_reason', 'Cancelled by user')
        instance.save()
        
    def perform_update(self, serializer):
        # Allow partial updates like confirm/cancel if authorized
        serializer.save()

class AvailableSlotsView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        provider_id = request.query_params.get('provider_id')
        date_str = request.query_params.get('date') # YYYY-MM-DD
        
        if not provider_id or not date_str:
            return Response({'error': 'provider_id and date are required'}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        except ValueError:
            return Response({'error': 'Invalid date format, use YYYY-MM-DD'}, status=status.HTTP_400_BAD_REQUEST)
            
        provider = HealthcareProvider.objects.filter(provider_id=provider_id).first()
        if not provider:
            return Response({'error': 'Provider not found'}, status=status.HTTP_404_NOT_FOUND)
            
        # Dummy slots generation (9 AM to 5 PM, 30 min intervals)
        slots = []
        start_time = datetime.combine(target_date, datetime.strptime("09:00", "%H:%M").time())
        end_time = datetime.combine(target_date, datetime.strptime("17:00", "%H:%M").time())
        
        # Get existing appointments for the provider on this day
        existing_appointments = Appointment.objects.filter(
            provider=provider,
            scheduled_at__date=target_date,
            status__in=['pending', 'confirmed']
        ).values_list('scheduled_at', flat=True)
        
        current_time = start_time
        while current_time < end_time:
            # Check if current_time exists in existing_appointments
            # NOTE: this is a simple check, in a real system we'd check ranges
            is_booked = any(
                app_time.replace(tzinfo=None) == current_time 
                for app_time in existing_appointments
            )
            
            if not is_booked:
                slots.append(current_time.strftime("%Y-%m-%dT%H:%M:%S"))
                
            current_time += timedelta(minutes=30)
            
        return Response({'available_slots': slots})
