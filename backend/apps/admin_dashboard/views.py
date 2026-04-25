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

class PlatformDashboardView(APIView):
    permission_classes = [IsSuperAdminUser]

    def get(self, request):
        total_patients = Patient.objects.count()
        total_providers = HealthcareProvider.objects.filter(verification_status='approved').count()
        pending_providers = HealthcareProvider.objects.filter(verification_status='pending').count()
        total_consultations = Consultation.objects.count()
        revenue = Payment.objects.filter(status='success').aggregate(Sum('platform_fee'))['platform_fee__sum'] or 0.00
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
        if str(url).startswith('http://') or str(url).startswith('https://'):
            return url
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
                return Response({'status': f'Provider {status_val}'})
            return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)
        except HealthcareProvider.DoesNotExist:
            return Response({'error': 'Provider not found'}, status=status.HTTP_404_NOT_FOUND)

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
            revenue=Sum('platform_fee')
        ).order_by('date')

        return Response(list(daily_revenue))
