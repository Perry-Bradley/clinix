from rest_framework import generics, permissions, status
import logging

logger = logging.getLogger(__name__)

from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Sum, Count, Avg, Q
from django.utils import timezone
from django.conf import settings
from django.core.files.storage import default_storage
import os
from .models import HealthcareProvider, ProviderCredential, ProviderReview, Specialty
from .serializers import ProviderProfileSerializer, ProviderCredentialSerializer, ProviderPublicSerializer, ProviderReviewSerializer, ProviderReviewCreateSerializer, SpecialtySerializer
from apps.payments.models import ProviderWallet, WalletTransaction, WithdrawalRequest
from apps.patients.models import Patient
from apps.locations.models import Location
from apps.appointments.models import Appointment
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

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
        
    def create(self, request, *args, **kwargs):
        provider = HealthcareProvider.objects.get(provider_id=self.request.user)
        document_type = request.data.get('document_type')
        upload = request.FILES.get('document')
        document_url = request.data.get('document_url')

        if not document_type:
            return Response({'document_type': 'This field is required.'}, status=status.HTTP_400_BAD_REQUEST)
        if not upload and not document_url:
            return Response({'document': 'Please attach a file or provide document_url.'}, status=status.HTTP_400_BAD_REQUEST)

        if upload:
            ext = os.path.splitext(upload.name)[1] or '.jpg'
            relative_path = default_storage.save(
                f'provider_kyc/{provider.provider_id_id}/{document_type}_{timezone.now().strftime("%Y%m%d%H%M%S")}{ext}',
                upload,
            )
            file_url = settings.MEDIA_URL + relative_path.replace('\\', '/')
        else:
            file_url = document_url

        credential, _ = ProviderCredential.objects.update_or_create(
            provider=provider,
            document_type=document_type,
            defaults={'document_url': file_url, 'is_verified': False},
        )
        provider.verification_status = 'pending'
        provider.verification_notes = ''
        provider.verified_at = None
        provider.verified_by = None
        provider.save(update_fields=['verification_status', 'verification_notes', 'verified_at', 'verified_by'])

        serializer = self.get_serializer(credential)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

class ProviderScheduleView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from .models import ProviderSchedule
        provider = HealthcareProvider.objects.get(provider_id=request.user)
        schedules = ProviderSchedule.objects.filter(provider=provider).order_by('day')
        day_order = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
        data = []
        for s in schedules:
            data.append({
                'day': s.day,
                'start_time': s.start_time.strftime('%H:%M') if s.start_time else None,
                'end_time': s.end_time.strftime('%H:%M') if s.end_time else None,
                'is_working': s.is_working,
            })
        # Fill missing days
        existing_days = {d['day'] for d in data}
        for day in day_order:
            if day not in existing_days:
                data.append({'day': day, 'start_time': None, 'end_time': None, 'is_working': False})
        data.sort(key=lambda x: day_order.index(x['day']))
        return Response({'is_available': provider.is_available, 'schedules': data})

    def post(self, request):
        from .models import ProviderSchedule
        from datetime import time as dt_time
        provider = HealthcareProvider.objects.get(provider_id=request.user)

        # Handle availability toggle
        if 'is_available' in request.data and 'schedules' not in request.data:
            provider.is_available = request.data.get('is_available', True)
            provider.save(update_fields=['is_available'])
            return Response({'is_available': provider.is_available})

        # Handle schedule update
        schedules = request.data.get('schedules', [])
        for entry in schedules:
            day = entry.get('day')
            if not day:
                continue
            is_working = entry.get('is_working', False)
            start_str = entry.get('start_time')
            end_str = entry.get('end_time')

            start_time = None
            end_time = None
            if start_str:
                parts = start_str.split(':')
                start_time = dt_time(int(parts[0]), int(parts[1]))
            if end_str:
                parts = end_str.split(':')
                end_time = dt_time(int(parts[0]), int(parts[1]))

            ProviderSchedule.objects.update_or_create(
                provider=provider, day=day,
                defaults={
                    'start_time': start_time or dt_time(8, 0),
                    'end_time': end_time or dt_time(17, 0),
                    'is_working': is_working,
                },
            )

        return Response({'message': 'Schedule updated'})

class ProviderEarningsView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        provider = HealthcareProvider.objects.get(provider_id=request.user)
        wallet, _ = ProviderWallet.objects.get_or_create(provider=provider)
        
        # Get recent transactions
        transactions = WalletTransaction.objects.filter(wallet=wallet).order_by('-created_at')[:10]
        tx_data = []
        for tx in transactions:
            tx_data.append({
                'id': tx.id,
                'amount': tx.amount,
                'type': tx.transaction_type,
                'reference': tx.reference,
                'date': tx.created_at
            })
            
        return Response({
            'balance': wallet.balance,
            'currency': 'XAF',
            'pending_withdrawals': WithdrawalRequest.objects.filter(provider=provider, status__in=['pending', 'approved']).aggregate(total=Sum('amount'))['total'] or 0,
            'verification_status': provider.verification_status,
            'consultation_fee': provider.consultation_fee,
            'recent_transactions': tx_data
        })

class ProviderWithdrawalView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        provider = HealthcareProvider.objects.get(provider_id=request.user)
        wallet, _ = ProviderWallet.objects.get_or_create(provider=provider)
        
        amount = float(request.data.get('amount', 0))
        method = request.data.get('method')
        details = request.data.get('details')

        if provider.verification_status != 'approved':
            return Response({'error': 'Your profile must be verified before withdrawals are allowed.'}, status=status.HTTP_400_BAD_REQUEST)

        if amount <= 0:
            return Response({'error': 'Invalid amount'}, status=status.HTTP_400_BAD_REQUEST)
        
        if amount > wallet.balance:
            return Response({'error': 'Insufficient balance'}, status=status.HTTP_400_BAD_REQUEST)

        withdrawal = WithdrawalRequest.objects.create(
            provider=provider,
            amount=amount,
            payout_method=method,
            payout_details=details
        )
        
        return Response({
            'message': 'Withdrawal request submitted',
            'request_id': withdrawal.id
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

class SpecialtyListView(generics.ListAPIView):
    """Public list of admin-configured specialties.

    Used by the mobile provider signup screen to populate the dropdown,
    and by the AI doctor-recommendation flow to map AI-detected specialty
    keywords to a real Specialty record.
    """
    serializer_class = SpecialtySerializer
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def get_queryset(self):
        return Specialty.objects.filter(is_active=True)


class ProviderNearbyView(generics.ListAPIView):
    serializer_class = ProviderPublicSerializer
    permission_classes = [permissions.AllowAny]
    authentication_classes = []  # Allow requests with expired/no tokens

    def get_queryset(self):
        queryset = HealthcareProvider.objects.filter(verification_status='approved')
        specialization = self.request.query_params.get('specialization')
        provider_role = self.request.query_params.get('role')
        specialty_id = self.request.query_params.get('specialty_id')
        specialty_name = self.request.query_params.get('specialty')
        is_available = self.request.query_params.get('available')

        if specialty_id:
            queryset = queryset.filter(specialty_obj_id=specialty_id)
        elif specialty_name:
            # Match either the legacy `specialty` field or the related Specialty.name.
            queryset = queryset.filter(
                Q(specialty__icontains=specialty_name) |
                Q(specialty_obj__name__icontains=specialty_name)
            )
        if provider_role:
            queryset = queryset.filter(provider_role=provider_role)
        if specialization:
            queryset = queryset.filter(specialty__icontains=specialization)
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
                    location_type='residence', # Recommendation based on residence
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
    authentication_classes = []
    queryset = HealthcareProvider.objects.all() # Remove filter for debugging
    lookup_field = 'pk'

    def get_object(self):
        pk = self.kwargs.get('pk')
        logger.warning(f"DEBUG: Attempting to fetch provider with PK: {pk}")
        try:
            obj = HealthcareProvider.objects.get(pk=pk)
            logger.warning(f"DEBUG: Found provider: {obj}. Status: {obj.verification_status}")
            return obj
        except HealthcareProvider.DoesNotExist:
            logger.error(f"DEBUG: Provider WITH PK {pk} NOT FOUND IN DATABASE")
            raise


class ProviderReviewListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_authenticators(self):
        # Skip JWT auth on GET so expired tokens don't cause 401 on public reads
        if self.request and self.request.method == 'GET':
            return []
        return super().get_authenticators()

    def get_provider(self, pk):
        return HealthcareProvider.objects.get(pk=pk, verification_status='approved')

    def get(self, request, pk):
        provider = self.get_provider(pk)
        reviews = ProviderReview.objects.filter(provider=provider)
        serializer = ProviderReviewSerializer(reviews, many=True)
        return Response(serializer.data)

    def post(self, request, pk):
        if not request.user.is_authenticated:
            return Response({'error': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)

        provider = self.get_provider(pk)
        try:
            patient = Patient.objects.get(patient_id=request.user)
        except Patient.DoesNotExist:
            return Response({'error': 'Only patients can leave reviews.'}, status=status.HTTP_403_FORBIDDEN)

        serializer = ProviderReviewCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        appointment = serializer.validated_data.get('appointment')

        review, _ = ProviderReview.objects.update_or_create(
            provider=provider,
            patient=patient,
            appointment=appointment,
            defaults={
                'rating': serializer.validated_data['rating'],
                'comment': serializer.validated_data.get('comment'),
            }
        )

        aggregates = ProviderReview.objects.filter(provider=provider).aggregate(avg=Avg('rating'), count=Count('review_id'))
        provider.rating = round(float(aggregates['avg'] or 0), 2)
        provider.total_consultations = max(provider.total_consultations, aggregates['count'] or 0)
        provider.save(update_fields=['rating', 'total_consultations'])

        return Response(ProviderReviewSerializer(review).data, status=status.HTTP_201_CREATED)
