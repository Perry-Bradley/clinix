from rest_framework import generics, permissions, status
import logging
import re

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

def _haversine_km(lat1, lng1, lat2, lng2):
    """Great-circle distance between two lat/lng pairs in kilometres."""
    r = 6371.0
    lat1_r = math.radians(lat1)
    lat2_r = math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1_r) * math.cos(lat2_r) * math.sin(dlng / 2) ** 2
    )
    return 2 * r * math.asin(math.sqrt(a))


class ProviderRecommendedView(APIView):
    """Smart doctor matcher used by the AI consultation flow.

    Combines the patient's context (location, language, budget, urgency)
    with each provider's data to compute a transparent ranking score and a
    list of human-readable reasons for the patient to trust the suggestion.

    Query params (all optional):
        specialty       — name or keyword from the AI assessment
        urgency         — 'high' | 'standard' (default: 'standard')
        role            — 'doctor' | 'specialist' | 'generalist' | 'nurse'
        lat, lng        — patient's current coordinates
        language        — 'en' | 'fr'
        max_distance_km — hard cap on distance (filters out beyond this)
        max_fee         — soft budget ceiling (XAF)
        limit           — number of results (default 5, max 10)
    """
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def get(self, request):
        params = request.query_params
        specialty_query = (params.get('specialty') or '').strip()
        urgency = (params.get('urgency') or 'standard').lower()
        language = (params.get('language') or '').lower()
        role = (params.get('role') or '').lower()
        try:
            patient_lat = float(params.get('lat')) if params.get('lat') else None
            patient_lng = float(params.get('lng')) if params.get('lng') else None
        except (TypeError, ValueError):
            patient_lat = patient_lng = None
        try:
            max_fee = float(params.get('max_fee')) if params.get('max_fee') else None
        except (TypeError, ValueError):
            max_fee = None
        try:
            max_distance_km = (
                float(params.get('max_distance_km'))
                if params.get('max_distance_km') else None
            )
        except (TypeError, ValueError):
            max_distance_km = None
        try:
            limit = max(1, min(int(params.get('limit', 5)), 10))
        except (TypeError, ValueError):
            limit = 5

        candidates = HealthcareProvider.objects.filter(
            verification_status='approved',
        ).select_related('provider_id', 'specialty_obj').prefetch_related('locations')

        # Role filter — nurse vs doctor (generalist+specialist) -- so the AI
        # can route home-care cases to nurses only, and clinical cases to
        # doctors only.
        if role:
            if role == 'doctor':
                candidates = candidates.filter(provider_role__in=['generalist', 'specialist'])
            elif role in {'specialist', 'generalist', 'nurse'}:
                candidates = candidates.filter(provider_role=role)

        # Specialty fuzzy match — try exact, contains, and word-level overlap.
        if specialty_query:
            words = [w for w in re.split(r'\W+', specialty_query) if len(w) > 2]
            specialty_q = (
                Q(specialty_obj__name__icontains=specialty_query) |
                Q(other_specialty__icontains=specialty_query) |
                Q(specialty__icontains=specialty_query)
            )
            for w in words:
                specialty_q |= (
                    Q(specialty_obj__name__icontains=w) |
                    Q(other_specialty__icontains=w) |
                    Q(specialty__icontains=w) |
                    Q(bio__icontains=w)
                )
            specialty_matches = candidates.filter(specialty_q)
            # Fallback to all candidates if nothing matched the specialty —
            # patient still benefits from a recommendation.
            candidates = specialty_matches if specialty_matches.exists() else candidates

        scored = []
        for prov in candidates[:50]:  # cap to keep scoring cheap
            user = prov.provider_id
            reasons = []
            score = 0.0

            # ── Specialty fit ──────────────────────────────────────────────
            sp_name = (prov.specialty_obj.name if prov.specialty_obj else '') or prov.other_specialty or prov.specialty or ''
            if specialty_query and specialty_query.lower() in sp_name.lower():
                score += 8.0
                reasons.append(f'Specialises in {sp_name}')
            elif specialty_query and any(
                w.lower() in sp_name.lower()
                for w in re.split(r'\W+', specialty_query) if len(w) > 2
            ):
                score += 5.0
                reasons.append(f'Works in {sp_name}')
            elif sp_name:
                score += 1.0
                reasons.append(f'{sp_name}')

            # ── Rating + experience ────────────────────────────────────────
            rating = float(prov.rating or 0)
            if rating >= 4.5:
                score += 4.0
                reasons.append(f'Top-rated ({rating:.1f}★)')
            elif rating >= 4.0:
                score += 2.5
            elif rating > 0:
                score += rating * 0.5

            consults = prov.total_consultations or 0
            if consults >= 100:
                score += 2.0
                reasons.append(f'{consults}+ consultations')
            elif consults >= 25:
                score += 1.0

            # ── Online / availability (urgency-weighted) ───────────────────
            online = False
            if user.last_seen:
                from django.utils import timezone
                diff = (timezone.now() - user.last_seen).total_seconds()
                online = diff < 300  # 5 min
            if online and urgency == 'high':
                score += 6.0
                reasons.insert(0, 'Online right now (urgent)')
            elif online:
                score += 2.5
                reasons.append('Online now')
            elif prov.is_available:
                score += 0.5

            # ── Distance ───────────────────────────────────────────────────
            distance_km = None
            if patient_lat is not None and patient_lng is not None:
                # Pick the closest of the provider's locations.
                best = None
                for loc in prov.locations.all():
                    if loc.latitude is None or loc.longitude is None:
                        continue
                    d = _haversine_km(
                        patient_lat, patient_lng,
                        float(loc.latitude), float(loc.longitude),
                    )
                    if best is None or d < best:
                        best = d
                if best is not None:
                    distance_km = round(best, 1)
                    # Hard filter: if the patient told the AI they wanted a
                    # provider within X km, drop anyone beyond that radius.
                    if max_distance_km is not None and best > max_distance_km:
                        continue
                    if best < 2:
                        score += 4.0
                        reasons.append(f'{distance_km} km away')
                    elif best < 10:
                        score += 2.0
                        reasons.append(f'{distance_km} km away')
                    elif best < 50:
                        score += 0.5
                    else:
                        score -= 1.0

            # ── Language preference ────────────────────────────────────────
            if language and user.language_pref and language == user.language_pref.lower():
                score += 1.5
                pretty = 'English' if language == 'en' else 'French'
                reasons.append(f'Speaks {pretty}')

            # ── Fee fit ────────────────────────────────────────────────────
            fee = float(prov.consultation_fee or 0)
            if max_fee is not None and fee > 0:
                if fee <= max_fee:
                    score += 1.0
                    reasons.append(f'Within your budget ({int(fee)} XAF)')
                else:
                    score -= 2.0

            # Build the public payload.
            provider_payload = ProviderPublicSerializer(prov, context={'request': request}).data
            provider_payload['score'] = round(score, 2)
            provider_payload['distance_km'] = distance_km
            provider_payload['match_reasons'] = reasons[:3]  # top 3 reasons
            scored.append((score, provider_payload))

        # Highest score first, then break ties by rating.
        scored.sort(key=lambda x: x[0], reverse=True)
        return Response([p for _, p in scored[:limit]])


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
