from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import ValidationError
from django.db.models import Q
from datetime import datetime, timedelta
from .models import Appointment
from .serializers import AppointmentSerializer, AppointmentDetailSerializer
from apps.patients.models import Patient
from apps.providers.models import HealthcareProvider, ProviderSchedule

class AppointmentListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'GET':
            return AppointmentDetailSerializer
        return AppointmentSerializer

    def get_queryset(self):
        user = self.request.user
        qs = Appointment.objects.select_related(
            'patient',
            'patient__patient_id',
            'provider',
            'provider__provider_id',
            'consultation',
        )
        if user.user_type == 'patient':
            # Patients see their non-cancelled appointments — pending ones
            # are kept so they can resume payment, but cancelled / no-show
            # are hidden because they're effectively dead records.
            return (
                qs.filter(patient__patient_id=user)
                .exclude(status__in=['cancelled', 'no_show'])
                .order_by('-scheduled_at')
            )
        if user.user_type == 'provider':
            # Providers must NOT see appointments that haven't been paid
            # for yet. Only confirmed / completed / cancelled / no-show
            # appointments belong on the doctor's dashboard.
            return (
                qs.filter(provider__provider_id=user)
                .exclude(status='pending')
                .order_by('-scheduled_at')
            )
        return Appointment.objects.none()

    def perform_create(self, serializer):
        patient = Patient.objects.get(patient_id=self.request.user)
        provider = serializer.validated_data['provider']
        scheduled_at = serializer.validated_data['scheduled_at']
        duration = serializer.validated_data.get('duration_minutes', 30)
        appointment_type = serializer.validated_data.get('appointment_type', 'virtual')
        appointment_end = scheduled_at + timedelta(minutes=duration)

        # Lab tests + home treatments are nurse-driven services. Nurses travel
        # to the patient on demand, so we don't gate them on a strict working-
        # hours schedule or clash window. The patient picks a slot and we let
        # the nurse manage their own bookings.
        is_service = appointment_type in ('lab_test', 'home_treatment')

        if not is_service:
            weekday = scheduled_at.strftime('%A').lower()
            schedule = ProviderSchedule.objects.filter(provider=provider, day=weekday, is_working=True).first()
            if not schedule:
                raise ValidationError({'detail': 'Provider is not available on the selected day.'})

            start_time = scheduled_at.time()
            end_time = appointment_end.time()
            if start_time < schedule.start_time or end_time > schedule.end_time:
                raise ValidationError({'detail': 'Selected time is outside the provider\'s working hours.'})

            clash_exists = Appointment.objects.filter(
                provider=provider,
                scheduled_at__date=scheduled_at.date(),
                status__in=['pending', 'confirmed'],
                scheduled_at__lt=appointment_end,
            ).filter(
                Q(scheduled_at__gte=scheduled_at) |
                Q(scheduled_at__lt=scheduled_at, scheduled_at__gte=scheduled_at - timedelta(minutes=duration))
            ).exists()

            if clash_exists:
                raise ValidationError({'detail': 'This doctor is not free at the selected time.'})

        appointment = serializer.save(patient=patient, status='pending')

        # Notify the provider when a service request comes in so nurses see
        # the new home visit / lab test in their notifications immediately.
        if is_service:
            try:
                from apps.notifications.tasks import send_notification
                patient_name = (
                    getattr(patient.patient_id, 'full_name', None) or 'A patient'
                )
                label = 'home visit' if appointment_type == 'home_treatment' else 'lab test'
                service = appointment.service_name or label
                send_notification.delay(
                    str(appointment.provider.provider_id.user_id),
                    f'New {label} request',
                    f'{patient_name} booked {service} — {scheduled_at.strftime("%b %d, %H:%M")}',
                    'appointment',
                    {'appointment_id': str(appointment.appointment_id)},
                )
            except Exception:
                pass

class AppointmentDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = AppointmentDetailSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = Appointment.objects.select_related(
            'patient',
            'patient__patient_id',
            'provider',
            'provider__provider_id',
            'consultation',
        )
        if user.user_type == 'patient':
            return qs.filter(patient__patient_id=user)
        if user.user_type == 'provider':
            return qs.filter(provider__provider_id=user)
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
            
        weekday = target_date.strftime('%A').lower()
        schedule = ProviderSchedule.objects.filter(provider=provider, day=weekday, is_working=True).first()
        if not schedule:
            return Response({'available_slots': []})

        slots = []
        slot_minutes = 30
        start_time = datetime.combine(target_date, schedule.start_time)
        end_time = datetime.combine(target_date, schedule.end_time)
        
        # Get existing appointments for the provider on this day
        existing_appointments = Appointment.objects.filter(
            provider=provider,
            scheduled_at__date=target_date,
            status__in=['pending', 'confirmed']
        ).values_list('scheduled_at', flat=True)
        
        current_time = start_time
        while current_time < end_time:
            slot_end = current_time + timedelta(minutes=slot_minutes)
            is_booked = any(
                app_time.replace(tzinfo=None) < slot_end and (app_time.replace(tzinfo=None) + timedelta(minutes=30)) > current_time
                for app_time in existing_appointments
            )
            
            if not is_booked and current_time >= datetime.now():
                slots.append(current_time.strftime("%Y-%m-%dT%H:%M:%S"))
                
            current_time += timedelta(minutes=slot_minutes)
            
        return Response({'available_slots': slots})
