from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Sum, Count
from django.db import models
from django.utils import timezone
from .permissions import IsSuperAdminUser
from apps.accounts.models import User
from apps.patients.models import Patient
from apps.providers.models import HealthcareProvider, ProviderCredential, Specialty
from apps.providers.serializers import SpecialtySerializer
from apps.appointments.models import Appointment
from apps.consultations.models import Consultation
from apps.payments.models import Payment
from apps.accounts.serializers import UserSerializer
from apps.providers.serializers import ProviderCredentialSerializer
from apps.appointments.serializers import AppointmentDetailSerializer
from .serializers import AdminPatientSerializer
from apps.payments.models import WithdrawalRequest, ProviderWallet, WalletTransaction
from django.db.models.functions import TruncDate
import csv
from django.http import HttpResponse
from django.conf import settings
import os
import time
import requests as http_requests
import logging
from apps.locations.models import Pharmacy

logger = logging.getLogger(__name__)


def _agreement(ai_decision, admin_decision):
    """Did the AI's confident call match the human? None = AI abstained (review)."""
    if ai_decision == 'approve':
        return admin_decision == 'approved'
    if ai_decision == 'reject':
        return admin_decision == 'rejected'
    return None


def _write_decision_log(provider, admin_decision, decided_by, ai):
    """Create one VerificationDecisionLog row from an AI assessment dict (either
    the snapshot the dashboard already had, or one freshly computed)."""
    from .models import VerificationDecisionLog
    ai = ai or {}
    ai_decision = ai.get('overall_decision') or ai.get('decision') or ''
    prob = ai.get('match_probability')
    if prob is None:
        prob = (ai.get('match_percent') or 0) / 100.0
    VerificationDecisionLog.objects.create(
        provider_user_id=provider.provider_id.user_id,
        provider_name=provider.provider_id.full_name or '',
        ai_decision=ai_decision,
        ai_match_probability=float(prob or 0),
        ai_checks_passed=int(ai.get('checks_passed') or 0),
        ai_checks_failed=int(ai.get('checks_failed') or 0),
        ai_model=ai.get('model') or '',
        admin_decision=admin_decision,
        decided_by=decided_by,
        agreed=_agreement(ai_decision, admin_decision),
    )


def _log_verification_decision(provider, admin_decision, decided_by, ai_snapshot=None):
    """Log the AI-vs-human decision for accuracy tracking. If the dashboard sent
    its AI snapshot we log it immediately (cheap); otherwise (e.g. quick-approve
    from the list) we compute the assessment on a background thread so the
    admin's action stays instant."""
    if ai_snapshot:
        try:
            _write_decision_log(provider, admin_decision, decided_by, ai_snapshot)
        except Exception:
            logger.exception('Shadow-mode decision log (snapshot) failed')
        return

    def _work():
        from django.db import connection
        try:
            from apps.ai_engine.verification import assess_provider
            from apps.ai_engine.document_extraction import extract_document
            creds = list(ProviderCredential.objects.filter(provider=provider))
            extracted = [{
                'document_type': c.document_type,
                'label': c.get_document_type_display(),
                'fields': extract_document(c.document_url, c.document_type),
            } for c in creds]
            result = assess_provider(
                provider.provider_id.full_name or '', provider.license_number or '', extracted)
            _write_decision_log(provider, admin_decision, decided_by, result)
        except Exception:
            logger.exception('Shadow-mode decision log (computed) failed')
        finally:
            connection.close()

    import threading
    threading.Thread(target=_work, daemon=True).start()


class PlatformDashboardView(APIView):
    permission_classes = [IsSuperAdminUser]

    def get(self, request):
        total_patients = Patient.objects.count()
        total_providers = HealthcareProvider.objects.filter(verification_status='approved').count()
        pending_providers = HealthcareProvider.objects.filter(verification_status='pending').count()
        total_consultations = Consultation.objects.count()
        # The platform takes no commission (platform_fee is 0), so "revenue"
        # here means the gross money collected from patients and held by the
        # platform — i.e. the full successful-payment amount. Net of payouts is
        # the balance still held (owed to providers).
        revenue = Payment.objects.filter(status='success').aggregate(Sum('amount'))['amount__sum'] or 0.00
        pending_withdrawals = WithdrawalRequest.objects.filter(status='pending').count()
        total_payouts = WithdrawalRequest.objects.filter(status='completed').aggregate(Sum('amount'))['amount__sum'] or 0.00
        
        return Response({
            'total_patients': total_patients,
            'total_providers': total_providers,
            'pending_verifications': pending_providers,
            'total_consultations': total_consultations,
            'total_revenue': revenue,
            'pending_withdrawals': pending_withdrawals,
            'total_payouts': total_payouts
        })

class UserListView(generics.ListAPIView):
    """Admin user directory with provider/specialty enrichment."""
    serializer_class = UserSerializer
    permission_classes = [IsSuperAdminUser]

    def get_queryset(self):
        qs = User.objects.all().order_by('-created_at')
        user_type = self.request.query_params.get('user_type')
        search = self.request.query_params.get('search')
        if user_type and user_type != 'all':
            qs = qs.filter(user_type=user_type)
        if search:
            qs = qs.filter(
                models.Q(full_name__icontains=search) |
                models.Q(email__icontains=search) |
                models.Q(phone_number__icontains=search)
            )
        return qs

    def list(self, request, *args, **kwargs):
        qs = self.filter_queryset(self.get_queryset())
        page = self.paginate_queryset(qs)
        users = page if page is not None else qs

        # Pre-fetch provider rows for the users on this page so we can
        # surface specialty / role / verification in a single response.
        user_ids = [u.user_id for u in users]
        providers = {
            p.provider_id_id: p
            for p in HealthcareProvider.objects.filter(provider_id__in=user_ids)
                .select_related('specialty_obj')
        }

        data = []
        for u in users:
            base = UserSerializer(u).data
            prov = providers.get(u.user_id)
            base['provider'] = None
            if prov is not None:
                base['provider'] = {
                    'provider_role': prov.provider_role,
                    'specialty': prov.specialty,
                    'specialty_name': prov.specialty_obj.name if prov.specialty_obj else None,
                    'verification_status': prov.verification_status,
                    'license_number': prov.license_number,
                    'consultation_fee': str(prov.consultation_fee),
                }
            data.append(base)

        if page is not None:
            return self.get_paginated_response(data)
        return Response(data)


class UserDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Admin user CRUD — view, edit, or delete."""
    serializer_class = UserSerializer
    permission_classes = [IsSuperAdminUser]
    queryset = User.objects.all()


class UserResetPasswordView(APIView):
    """Admin-only: force-set a user's password."""
    permission_classes = [IsSuperAdminUser]

    def post(self, request, pk):
        new_password = request.data.get('password')
        if not new_password or len(new_password) < 6:
            return Response(
                {'error': 'Password must be at least 6 characters.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            user = User.objects.get(user_id=pk)
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)
        user.set_password(new_password)
        user.save()
        return Response({'status': 'password updated', 'user_id': str(user.user_id)})

class AdminPatientListView(generics.ListCreateAPIView):
    serializer_class = AdminPatientSerializer
    permission_classes = [IsSuperAdminUser]
    queryset = Patient.objects.all().order_by('-patient_id__created_at')

class AdminPatientDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = AdminPatientSerializer
    permission_classes = [IsSuperAdminUser]
    queryset = Patient.objects.all()

class AdminSpecialtyListCreateView(generics.ListCreateAPIView):
    """Admin-only catalogue management: list and create specialties."""
    serializer_class = SpecialtySerializer
    permission_classes = [IsSuperAdminUser]
    queryset = Specialty.objects.all()


class AdminSpecialtyDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Admin-only: edit / deactivate / delete a specialty."""
    serializer_class = SpecialtySerializer
    permission_classes = [IsSuperAdminUser]
    queryset = Specialty.objects.all()
    lookup_field = 'specialty_id'


class VerificationListView(APIView):
    permission_classes = [IsSuperAdminUser]
    
    def get(self, request):
        providers = HealthcareProvider.objects.filter(verification_status='pending')
        data = []
        for p in providers:
            data.append({
                'provider_id': p.provider_id.user_id,
                'name': p.provider_id.full_name or str(p.provider_id.user_id),
                'specialization': p.other_specialty or p.specialty,
                'license_number': p.license_number,
                'submitted_at': p.provider_id.created_at,
                'verification_notes': p.verification_notes,
            })
        return Response(data)

class VerificationDetailView(APIView):
    permission_classes = [IsSuperAdminUser]

    def _absolute_url(self, request, url):
        if not url:
            return url
        url = str(url)
        if url.startswith('http://') or url.startswith('https://'):
            return url
        # Ensure a leading slash so build_absolute_uri resolves from site root,
        # not relative to the current API path.
        if not url.startswith('/'):
            url = '/' + url
        return request.build_absolute_uri(url)

    def get(self, request, pk):
        try:
            provider = HealthcareProvider.objects.get(provider_id=pk)
            credentials = ProviderCredential.objects.filter(provider=provider)
            cd_data = []
            for c in credentials:
                cd_data.append({
                    'type': 'image',
                    'label': c.document_type.capitalize(),
                    'url': self._absolute_url(request, c.document_url)
                })
                
            return Response({
                'id': provider.provider_id.user_id,
                'name': provider.provider_id.full_name or str(provider.provider_id.user_id),
                'spec': provider.other_specialty or provider.specialty,
                'license': provider.license_number,
                'verification_status': provider.verification_status,
                'verification_notes': provider.verification_notes,
                'documents': cd_data
            })
        except HealthcareProvider.DoesNotExist:
            return Response({'error': 'Provider not found'}, status=status.HTTP_404_NOT_FOUND)
        
    def patch(self, request, pk):
        try:
            provider = HealthcareProvider.objects.get(provider_id=pk)
            status_val = request.data.get('status') # 'approved' or 'rejected'
            notes = request.data.get('notes', '')
            
            if status_val in ['approved', 'rejected']:
                provider.verification_status = status_val
                provider.verification_notes = notes
                provider.verified_at = timezone.now()
                provider.verified_by = request.user
                provider.save()
                # Shadow-mode: record the AI's recommendation vs this human
                # decision so we can measure real accuracy over time.
                _log_verification_decision(
                    provider, status_val,
                    decided_by=getattr(request.user, 'email', '') or '',
                    ai_snapshot=request.data.get('ai'),
                )
                return Response({'status': f'Provider {status_val}'})
            return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)
        except HealthcareProvider.DoesNotExist:
            return Response({'error': 'Provider not found'}, status=status.HTTP_404_NOT_FOUND)


class VerificationAICheckView(APIView):
    """Autonomous provider verification. Combines:
      1) a record-linkage match of the signup name + license number against the
         CMC/ONMC registry (scikit-learn Logistic Regression), and
      2) Groq-vision extraction of the uploaded National ID + medical-license
         documents, cross-checked against the signup details and the registry.
    Returns a match probability, per-document field extraction, a check-list,
    and an overall recommended decision (approve / review / reject)."""
    permission_classes = [IsSuperAdminUser]

    def get(self, request, pk):
        try:
            provider = HealthcareProvider.objects.select_related('provider_id').get(provider_id=pk)
        except HealthcareProvider.DoesNotExist:
            return Response({'error': 'Provider not found'}, status=status.HTTP_404_NOT_FOUND)

        from apps.ai_engine.verification import assess_provider
        from apps.ai_engine.document_extraction import extract_document
        from concurrent.futures import ThreadPoolExecutor

        creds = list(ProviderCredential.objects.filter(provider=provider))

        def _read(cred):
            return {
                'document_type': cred.document_type,
                'label': cred.get_document_type_display(),
                'fields': extract_document(cred.document_url, cred.document_type),
            }

        extracted = []
        if creds:
            with ThreadPoolExecutor(max_workers=min(4, len(creds))) as ex:
                extracted = list(ex.map(_read, creds))

        full_name = provider.provider_id.full_name or ''
        result = assess_provider(full_name, provider.license_number or '', extracted)
        result['provider_id'] = str(provider.provider_id.user_id)
        result['provider_name'] = full_name
        result['provider_license'] = provider.license_number
        return Response(result)


class VerificationAIStatsView(APIView):
    """Live, real-world accuracy of the AI verifier — computed from shadow-mode
    logs of AI-recommendation vs. actual-admin-decision. Empty until admins
    start deciding; stabilises after MIN_FOR_STABLE confident predictions."""
    permission_classes = [IsSuperAdminUser]
    MIN_FOR_STABLE = 20

    def get(self, request):
        from .models import VerificationDecisionLog
        qs = VerificationDecisionLog.objects.all()
        total = qs.count()
        confident = qs.exclude(agreed__isnull=True)
        n_conf = confident.count()
        agreed = confident.filter(agreed=True).count()
        false_approve = qs.filter(ai_decision='approve', admin_decision='rejected').count()
        false_reject = qs.filter(ai_decision='reject', admin_decision='approved').count()

        return Response({
            'total_decisions': total,
            'confident_predictions': n_conf,
            'agreed': agreed,
            'accuracy_percent': round(agreed / n_conf * 100, 1) if n_conf else None,
            'false_approve': false_approve,   # AI said approve, human rejected (the costly error)
            'false_reject': false_reject,     # AI said reject, human approved
            'min_for_stable': self.MIN_FOR_STABLE,
            'enough_data': n_conf >= self.MIN_FOR_STABLE,
        })


class PlatformAppointmentsView(generics.ListAPIView):
    serializer_class = AppointmentDetailSerializer
    permission_classes = [IsSuperAdminUser]

    def get_queryset(self):
        qs = Appointment.objects.select_related(
            'patient', 'patient__patient_id',
            'provider', 'provider__provider_id',
        ).order_by('-created_at')
        status_val = self.request.query_params.get('status')
        appt_type = self.request.query_params.get('type')
        search = self.request.query_params.get('search', '').strip()
        if status_val:
            qs = qs.filter(status=status_val)
        if appt_type:
            qs = qs.filter(appointment_type=appt_type)
        if search:
            qs = qs.filter(
                models.Q(patient__patient_id__full_name__icontains=search) |
                models.Q(provider__provider_id__full_name__icontains=search)
            )
        return qs

def _parse_days(request, default=30, maximum=365):
    try:
        days = int(request.query_params.get('days', default))
    except (TypeError, ValueError):
        days = default
    return max(1, min(days, maximum))


class AnalyticsRevenueView(APIView):
    """Daily platform revenue (successful payments) for the chart on the
    admin dashboard. `?days=N` controls the window (default 30)."""
    permission_classes = [IsSuperAdminUser]

    def get(self, request):
        days = _parse_days(request)
        since = timezone.now() - timezone.timedelta(days=days)
        rows = (
            Payment.objects.filter(status='success', initiated_at__gte=since)
            .annotate(date=TruncDate('initiated_at'))
            .values('date')
            .annotate(
                # No platform commission, so chart "revenue" = gross collected.
                revenue=Sum('amount'),
                volume=Sum('amount'),
                payments=Count('pk'),
            )
            .order_by('date')
        )
        data = [
            {
                'date': r['date'].isoformat(),
                'revenue': float(r['revenue'] or 0),
                'volume': float(r['volume'] or 0),
                'payments': r['payments'],
            }
            for r in rows if r['date']
        ]
        return Response({'data': data, 'days': days})


class AnalyticsConsultationView(APIView):
    """Daily consultation counts. `?days=N` controls the window (default 30)."""
    permission_classes = [IsSuperAdminUser]

    def get(self, request):
        days = _parse_days(request)
        since = timezone.now() - timezone.timedelta(days=days)
        rows = (
            Consultation.objects.filter(created_at__gte=since)
            .annotate(date=TruncDate('created_at'))
            .values('date')
            .annotate(consultations=Count('pk'))
            .order_by('date')
        )
        data = [
            {'date': r['date'].isoformat(), 'consultations': r['consultations']}
            for r in rows if r['date']
        ]
        return Response({'data': data, 'days': days})


class ExportCSVReportView(APIView):
    """CSV export. `?report=appointments` (default) or `?report=payments`."""
    permission_classes = [IsSuperAdminUser]

    def get(self, request):
        report = request.query_params.get('report', 'appointments')
        if report not in ('appointments', 'payments'):
            report = 'appointments'

        response = HttpResponse(content_type='text/csv')
        stamp = timezone.now().strftime('%Y%m%d')
        response['Content-Disposition'] = f'attachment; filename="clinix_{report}_{stamp}.csv"'
        writer = csv.writer(response)

        if report == 'payments':
            writer.writerow(['Payment ID', 'Amount', 'Platform Fee', 'Provider Payout', 'Status', 'Initiated At', 'Completed At'])
            for p in Payment.objects.all().order_by('-initiated_at')[:5000]:
                writer.writerow([
                    str(p.pk), p.amount, p.platform_fee or '', p.provider_payout or '',
                    p.status,
                    p.initiated_at.isoformat() if p.initiated_at else '',
                    p.completed_at.isoformat() if p.completed_at else '',
                ])
        else:
            writer.writerow(['Appointment ID', 'Patient', 'Provider', 'Type', 'Status', 'Scheduled At'])
            qs = (
                Appointment.objects
                .select_related('patient__patient_id', 'provider__provider_id')
                .order_by('-scheduled_at')[:5000]
            )
            for a in qs:
                patient_name = getattr(getattr(a.patient, 'patient_id', None), 'full_name', '') or ''
                provider_name = getattr(getattr(a.provider, 'provider_id', None), 'full_name', '') or ''
                writer.writerow([
                    str(a.pk), patient_name, provider_name,
                    a.appointment_type, a.status,
                    a.scheduled_at.isoformat() if a.scheduled_at else '',
                ])
        return response

class AdminWithdrawalListView(APIView):
    permission_classes = [IsSuperAdminUser]

    def get(self, request):
        withdrawals = WithdrawalRequest.objects.all().order_by('-requested_at')
        data = []
        for w in withdrawals:
            data.append({
                'id': w.id,
                'provider_name': w.provider.provider_id.full_name or str(w.provider.provider_id.user_id),
                'amount': w.amount,
                'method': w.payout_method,
                'details': w.payout_details,
                'status': w.status,
                'date': w.requested_at,
                'admin_notes': w.admin_notes,
            })
        return Response(data)

class AdminWithdrawalActionView(APIView):
    permission_classes = [IsSuperAdminUser]

    def post(self, request, pk):
        withdrawal = WithdrawalRequest.objects.get(pk=pk)
        action = request.data.get('action') # 'approve' or 'complete' or 'reject'
        notes = request.data.get('notes', '')

        if action == 'approve':
            # Approve → immediately send money via CamPay disbursement
            withdrawal.status = 'approved'
            withdrawal.admin_notes = notes
            withdrawal.save()
            result = _disburse_via_campay(withdrawal)
            if result.get('ok'):
                withdrawal.status = 'completed'
                withdrawal.processed_at = timezone.now()
                withdrawal.save()
                # Deduct from wallet
                wallet = withdrawal.provider.wallet
                wallet.balance -= withdrawal.amount
                wallet.save()
                WalletTransaction.objects.create(
                    wallet=wallet,
                    amount=withdrawal.amount,
                    transaction_type='debit',
                    reference=f"WD-{withdrawal.id}"
                )
                return Response({'status': 'completed', 'reference': result.get('reference')})
            else:
                # Disbursement failed — keep status 'approved' so admin can retry
                return Response(
                    {'status': 'approved', 'error': result.get('error') or 'CamPay disbursement failed'},
                    status=status.HTTP_502_BAD_GATEWAY,
                )
        elif action == 'complete':
            # Manual mark-as-completed (bypass auto-disbursement)
            withdrawal.status = 'completed'
            withdrawal.processed_at = timezone.now()
            wallet = withdrawal.provider.wallet
            wallet.balance -= withdrawal.amount
            wallet.save()
            WalletTransaction.objects.create(
                wallet=wallet,
                amount=withdrawal.amount,
                transaction_type='debit',
                reference=f"WD-{withdrawal.id}"
            )
        elif action == 'reject':
            withdrawal.status = 'rejected'

        withdrawal.admin_notes = notes
        withdrawal.save()
        return Response({'status': f'Withdrawal {withdrawal.status}'})


def _disburse_via_campay(withdrawal):
    """Send money from the Clinix platform wallet to the provider's mobile money number."""
    import requests
    from django.conf import settings
    base_url = getattr(settings, 'CAMPAY_BASE_URL', '')
    username = getattr(settings, 'CAMPAY_USERNAME', '')
    password = getattr(settings, 'CAMPAY_PASSWORD', '')
    if not username or not password:
        return {'ok': False, 'error': 'CamPay credentials not configured'}

    try:
        token_res = requests.post(
            f'{base_url}/api/token/',
            json={'username': username, 'password': password},
            timeout=15,
        )
        if token_res.status_code != 200:
            return {'ok': False, 'error': 'Failed to get CamPay token'}
        token = token_res.json().get('token')

        # Clean phone to CamPay format (237XXXXXXXXX)
        phone = (withdrawal.payout_details or '').replace('+', '').replace(' ', '').replace('-', '')
        if not phone.startswith('237'):
            phone = '237' + phone.lstrip('0')

        payload = {
            'amount': str(int(withdrawal.amount)),
            'currency': 'XAF',
            'to': phone,
            'description': f'Clinix provider payout #{withdrawal.id}',
            'external_reference': f'WD-{withdrawal.id}',
        }
        r = requests.post(
            f'{base_url}/api/withdraw/',
            json=payload,
            headers={'Authorization': f'Token {token}', 'Content-Type': 'application/json'},
            timeout=30,
        )
        if r.status_code in (200, 201):
            data = r.json()
            return {'ok': True, 'reference': data.get('reference'), 'raw': data}
        return {'ok': False, 'error': f'CamPay {r.status_code}: {r.text[:200]}'}
    except requests.RequestException as e:
        return {'ok': False, 'error': str(e)}

class AdminRevenueStatsView(APIView):
    permission_classes = [IsSuperAdminUser]

    def get(self, request):
        # Daily revenue for the last 30 days
        thirty_days_ago = timezone.now() - timezone.timedelta(days=30)
        daily_revenue = Payment.objects.filter(
            status='success', 
            initiated_at__gte=thirty_days_ago
        ).annotate(
            date=TruncDate('initiated_at')
        ).values('date').annotate(
            # No platform commission, so "revenue" = gross collected amount.
            revenue=Sum('amount')
        ).order_by('date')

        return Response(list(daily_revenue))


# ── Pharmacy directory (Google Places sync + phone editing) ──────────────────

CAMEROON_CITIES = [
    ('Douala',      4.0511,  9.7679),
    ('Yaounde',     3.8480, 11.5021),
    ('Buea',        4.1527,  9.2403),
    ('Bafoussam',   5.4737, 10.4179),
    ('Bamenda',     5.9597, 10.1451),
    ('Garoua',      9.3017, 13.3920),
    ('Maroua',     10.5910, 14.3236),
    ('Ngaoundere',  7.3276, 13.5840),
    ('Limbe',       4.0213,  9.2014),
    ('Kumba',       4.6364,  9.4468),
]

PLACE_TYPES_TO_SYNC = ['pharmacy', 'hospital']


class PharmacyListView(APIView):
    permission_classes = [IsSuperAdminUser]

    def get(self, request):
        place_type = request.query_params.get('type')  # ?type=pharmacy or ?type=hospital
        qs = Pharmacy.objects.all()
        if place_type in PLACE_TYPES_TO_SYNC:
            qs = qs.filter(place_type=place_type)
        data = [
            {
                'id': p.id,
                'place_id': p.place_id,
                'name': p.name,
                'place_type': p.place_type,
                'address': p.address,
                'city': p.city,
                'phone_number': p.phone_number,
                'latitude': str(p.latitude) if p.latitude else None,
                'longitude': str(p.longitude) if p.longitude else None,
                'synced_at': p.synced_at,
            }
            for p in qs
        ]
        return Response(data)


def run_facility_sync() -> dict:
    """Fetch pharmacies + hospitals from Google Places and upsert into the DB.
    Shared by the admin sync endpoint and the weekly Celery task. Returns a
    summary dict ({'error': 'no_api_key'} when the key is missing)."""
    api_key = os.environ.get('GOOGLE_MAPS_API_KEY', '')
    if not api_key:
        return {'error': 'no_api_key'}

    created = updated = 0
    errors = []

    for place_type in PLACE_TYPES_TO_SYNC:
        for city_name, lat, lng in CAMEROON_CITIES:
            next_page_token = None
            for _ in range(3):  # up to 3 pages = 60 results per city per type
                params = {
                    'location': f'{lat},{lng}',
                    'radius': 50000,
                    'type': place_type,
                    'key': api_key,
                }
                if next_page_token:
                    params = {'pagetoken': next_page_token, 'key': api_key}

                try:
                    r = http_requests.get(
                        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
                        params=params,
                        timeout=15,
                    )
                    data = r.json()
                except Exception as e:
                    errors.append(f'{place_type}/{city_name}: {e}')
                    break

                for place in data.get('results', []):
                    place_id = place.get('place_id')
                    if not place_id:
                        continue
                    name = place.get('name', '')
                    address = place.get('vicinity', '')
                    p_lat = place.get('geometry', {}).get('location', {}).get('lat')
                    p_lng = place.get('geometry', {}).get('location', {}).get('lng')

                    obj, was_created = Pharmacy.objects.update_or_create(
                        place_id=place_id,
                        defaults={
                            'name': name,
                            'place_type': place_type,
                            'address': address,
                            'city': city_name,
                            'latitude': p_lat,
                            'longitude': p_lng,
                        },
                    )
                    if was_created:
                        created += 1
                    else:
                        updated += 1

                next_page_token = data.get('next_page_token')
                if not next_page_token:
                    break
                time.sleep(2)  # required delay before using next_page_token

    return {
        'created': created,
        'updated': updated,
        'total': Pharmacy.objects.count(),
        'errors': errors,
    }


class PharmacySyncView(APIView):
    """Fetch pharmacies and hospitals from Google Places API and upsert into the DB."""
    permission_classes = [IsSuperAdminUser]

    def post(self, request):
        result = run_facility_sync()
        if result.get('error') == 'no_api_key':
            return Response({'error': 'GOOGLE_MAPS_API_KEY not configured'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        return Response(result)


class PharmacyPhoneView(APIView):
    """PATCH to update a pharmacy's phone number."""
    permission_classes = [IsSuperAdminUser]

    def patch(self, request, pk):
        try:
            pharmacy = Pharmacy.objects.get(pk=pk)
        except Pharmacy.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

        phone = request.data.get('phone_number', '').strip()
        pharmacy.phone_number = phone or None
        pharmacy.save(update_fields=['phone_number'])
        return Response({
            'id': pharmacy.id,
            'name': pharmacy.name,
            'place_type': pharmacy.place_type,
            'phone_number': pharmacy.phone_number,
        })


# ── ONMC doctor directory (onmc.app/tableau_de_lordre) ──────────────────────
# Structure confirmed: <h2>FULL NAME</h2><p>REG_NO/YEAR Médecin</p>
# 64 pages at ?page=N, ~200 doctors per page, 12 688 total.

import re as _re

ONMC_BASE = 'https://onmc.app'
ONMC_DIRECTORY = f'{ONMC_BASE}/tableau_de_lordre'
ONMC_TOTAL_PAGES = 64

_ONMC_CACHE: dict = {'data': [], 'fetched_at': 0, 'error': None, 'pages_scraped': 0}
CMC_CACHE_TTL = 3600  # 1 hour

_ONMC_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
    'Referer': ONMC_BASE,
}

# Keep old alias so any existing code that imports CMC_CACHE_TTL still works
_CMC_CACHE = _ONMC_CACHE
CMC_DIRECTORY = ONMC_DIRECTORY


_REG_NO_RE = _re.compile(r'P?\d{3,6}\s*/\s*\d{4}')


def _extract_reg_no(text: str) -> str:
    """Pull the registration number (e.g. '13574/2024', or 'P1234/2023') out of
    a doctor's detail text. Falls back to stripping the 'Médecin' suffix if the
    number pattern isn't found."""
    text = text or ''
    m = _REG_NO_RE.search(text)
    if m:
        return m.group(0).replace(' ', '')
    return _re.sub(r'\s*[Mm][eé]decin.*$', '', text).strip()


def _parse_onmc_page(html: str) -> list:
    """
    Parse one page of onmc.app/tableau_de_lordre.
    Each entry: <h2>NAME</h2> followed by <p>REG_NO/YEAR Médecin...</p>
    Uses multiple fallback strategies to locate the registration <p>.
    """
    entries = []
    try:
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(html, 'lxml')
        # Each doctor card on onmc.app is:
        #   <h2 class="bloc-nom">NAME</h2>
        #   <span class="bloc-numero">REG_NO/YEAR</span>
        #   <span class="bloc-specialite">Médecin</span>
        cards = soup.find_all('h2', class_='bloc-nom') or soup.find_all('h2')
        for h2 in cards:
            name = ' '.join(h2.get_text().split()).strip()
            if not name or len(name) < 3:
                continue
            numero = h2.find_next('span', class_='bloc-numero')
            reg_no = _extract_reg_no(numero.get_text()) if numero else ''
            spec_node = h2.find_next('span', class_='bloc-specialite')
            spec = ' '.join(spec_node.get_text().split()).strip() if spec_node else 'Médecine'
            entries.append({
                'name': name,
                'specialization': spec or 'Médecine',
                'region': '',
                'registration_number': reg_no,
            })
    except ImportError:
        # Regex fallback when BeautifulSoup is unavailable.
        pairs = _re.findall(
            r'<h2[^>]*class="[^"]*bloc-nom[^"]*"[^>]*>(.*?)</h2>\s*'
            r'<span[^>]*class="[^"]*bloc-numero[^"]*"[^>]*>(.*?)</span>',
            html, _re.S,
        )
        for raw_name, raw_reg in pairs:
            name = ' '.join(_re.sub(r'<[^>]+>', '', raw_name).split()).strip()
            reg_no = _extract_reg_no(_re.sub(r'<[^>]+>', '', raw_reg))
            if name:
                entries.append({
                    'name': name,
                    'specialization': 'Médecine',
                    'region': '',
                    'registration_number': reg_no,
                })
    return entries


def _scrape_onmc_doctors(max_pages: int = ONMC_TOTAL_PAGES) -> tuple:
    """
    Scrape onmc.app/tableau_de_lordre across all pages.
    Returns (entries: list, error: str|None, pages_scraped: int).
    """
    all_entries = []
    error_msg = None
    pages_scraped = 0
    seen = set()

    for page_num in range(1, max_pages + 1):
        url = ONMC_DIRECTORY if page_num == 1 else f'{ONMC_DIRECTORY}?page={page_num}'
        try:
            resp = http_requests.get(url, timeout=12, headers=_ONMC_HEADERS, allow_redirects=True)
            if resp.status_code != 200:
                if page_num == 1:
                    error_msg = f'ONMC site returned HTTP {resp.status_code}.'
                break

            page_entries = _parse_onmc_page(resp.text)

            if not page_entries:
                # Empty page means we've gone past the last real page
                break

            new_count = 0
            for e in page_entries:
                key = e['name'].lower()
                if key not in seen:
                    seen.add(key)
                    all_entries.append(e)
                    new_count += 1

            pages_scraped = page_num

            if new_count == 0 and page_num > 1:
                break  # duplicate / past last page

        except http_requests.RequestException as exc:
            error_msg = str(exc)
            if page_num == 1:
                break  # can't even reach page 1
            # Non-fatal for later pages — keep what we have
            break

    if not all_entries and not error_msg:
        error_msg = 'Page fetched but no doctor records found — HTML structure may have changed.'

    return all_entries, error_msg, pages_scraped


_ONMC_SCRAPE_STATE = {'running': False, 'last': 0.0, 'result': None}


def _trigger_onmc_scrape() -> bool:
    """Kick off an ONMC scrape+store on a background thread (non-blocking).
    Debounced so rapid refreshes don't pile up. Records the last run's outcome
    in `_ONMC_SCRAPE_STATE['result']` so the view can surface why it did/didn't
    update. Returns True if a scrape is in progress/just started."""
    now = time.time()
    if _ONMC_SCRAPE_STATE['running']:
        return True
    if now - _ONMC_SCRAPE_STATE['last'] < 120:
        return False  # scraped very recently
    _ONMC_SCRAPE_STATE['running'] = True
    _ONMC_SCRAPE_STATE['last'] = now

    import threading
    from django.db import close_old_connections

    def _run():
        from .tasks import scrape_and_store_onmc
        try:
            close_old_connections()
            _ONMC_SCRAPE_STATE['result'] = scrape_and_store_onmc()
        except Exception as e:
            import logging
            logging.getLogger(__name__).exception('Background ONMC scrape failed')
            _ONMC_SCRAPE_STATE['result'] = {'stored': 0, 'error': repr(e)[:300]}
        finally:
            _ONMC_SCRAPE_STATE['running'] = False
            close_old_connections()

    threading.Thread(target=_run, daemon=True).start()
    return True


class CMCDoctorsView(APIView):
    """Return ONMC-registered doctors (onmc.app/tableau_de_lordre)."""
    permission_classes = [IsSuperAdminUser]

    def get(self, request):
        from django.db.models import Q
        from .models import OnmcDoctor

        force_refresh = request.query_params.get('refresh') == '1'

        # Serve from the DB (refreshed weekly by Celery Beat). A scrape is slow
        # (~64 pages), so NEVER run it inside the request — kick it off in the
        # background and return whatever's in the DB right now. Trigger only when
        # the admin asks (refresh=1) or the table has never been filled.
        # Always render instantly from the DB — NEVER scrape on navigation.
        # Scraping is a behind-the-scenes job (weekly Celery Beat). A manual
        # Refresh just kicks off a background re-scrape; it never blocks this
        # response or makes the page wait.
        scraping = _trigger_onmc_scrape() if force_refresh else False

        qs = OnmcDoctor.objects.all()
        total = qs.count()
        search = request.query_params.get('search', '').strip()
        if search:
            qs = qs.filter(
                Q(name__icontains=search) |
                Q(registration_number__icontains=search) |
                Q(region__icontains=search)
            )

        results = [
            {
                'name': d.name,
                'specialization': d.specialization,
                'region': d.region,
                'registration_number': d.registration_number,
            }
            for d in qs
        ]

        # Surface the LAST scrape's outcome so it's diagnosable why the table
        # did/didn't update (e.g. "stored 0 — source blocked", or an exception).
        last = _ONMC_SCRAPE_STATE.get('result')
        scrape_error = None
        if last and not last.get('stored'):
            scrape_error = last.get('error') or 'Last scrape stored 0 records.'

        latest = (OnmcDoctor.objects.order_by('-scraped_at')
                  .values_list('scraped_at', flat=True).first())
        return Response({
            'count': len(results),
            'total_scraped': total,
            'pages_scraped': (last or {}).get('pages', 0) if last else 0,
            'fetched_at': latest.timestamp() if latest else 0,
            'source': ONMC_DIRECTORY,
            'scraping': scraping,
            'scrape_error': scrape_error,
            'last_scrape': last,
            'results': results,
        })
