from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Sum, Count, Avg
from django.utils import timezone
from django.conf import settings
from django.core.files.storage import default_storage
import os
from .models import HealthcareProvider, ProviderCredential, ProviderReview
from .serializers import ProviderProfileSerializer, ProviderCredentialSerializer, ProviderPublicSerializer, ProviderReviewSerializer, ProviderReviewCreateSerializer
from apps.payments.models import ProviderWallet, WalletTransaction, WithdrawalRequest
from apps.patients.models import Patient
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

        if not document_type:
            return Response({'document_type': 'This field is required.'}, status=status.HTTP_400_BAD_REQUEST)
        if not upload:
            return Response({'document': 'Please attach a file.'}, status=status.HTTP_400_BAD_REQUEST)

        ext = os.path.splitext(upload.name)[1] or '.jpg'
        relative_path = default_storage.save(
            f'provider_kyc/{provider.provider_id_id}/{document_type}_{timezone.now().strftime("%Y%m%d%H%M%S")}{ext}',
            upload,
        )
        file_url = settings.MEDIA_URL + relative_path.replace('\\', '/')

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

class ProviderNearbyView(generics.ListAPIView):
    serializer_class = ProviderPublicSerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        queryset = HealthcareProvider.objects.filter(verification_status='approved')
        specialization = self.request.query_params.get('specialization')
        is_available = self.request.query_params.get('available')
        
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
    queryset = HealthcareProvider.objects.filter(verification_status='approved')
    lookup_field = 'provider_id'

class ProviderReviewListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_provider(self, provider_id):
        return HealthcareProvider.objects.get(provider_id=provider_id, verification_status='approved')

    def get(self, request, provider_id):
        provider = self.get_provider(provider_id)
        reviews = ProviderReview.objects.filter(provider=provider)
        serializer = ProviderReviewSerializer(reviews, many=True)
        return Response(serializer.data)

    def post(self, request, provider_id):
        if not request.user.is_authenticated:
            return Response({'error': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)

        provider = self.get_provider(provider_id)
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
