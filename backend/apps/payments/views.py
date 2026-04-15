from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from django.conf import settings
from .models import Payment, ProviderSubscription, PlatformSetting, ProviderWallet, WalletTransaction
from .serializers import PaymentSerializer, PlatformSettingSerializer
from apps.appointments.models import Appointment
from apps.patients.models import Patient
import uuid
import decimal
import logging
from django.db import transaction
from django.db.models import Q
import requests

logger = logging.getLogger(__name__)


def _mark_payment_success(payment):
    if payment.status == 'success':
        return payment

    with transaction.atomic():
        payment.status = 'success'
        payment.completed_at = timezone.now()
        payment.save(update_fields=['status', 'completed_at'])
        if payment.appointment:
            payment.appointment.status = 'confirmed'
            payment.appointment.save(update_fields=['status'])

        # Credit provider wallet
        if payment.provider and payment.provider_payout:
            wallet, _ = ProviderWallet.objects.get_or_create(provider=payment.provider)
            wallet.balance += payment.provider_payout
            wallet.save(update_fields=['balance'])
            WalletTransaction.objects.create(
                wallet=wallet,
                amount=payment.provider_payout,
                transaction_type='credit',
                reference=payment.transaction_ref,
            )
    return payment


# ─── CamPay Integration ───────────────────────────────────────────────────────

def _get_campay_token():
    """Get an access token from CamPay API."""
    base_url = getattr(settings, 'CAMPAY_BASE_URL', 'https://demo.campay.net')
    username = getattr(settings, 'CAMPAY_USERNAME', '')
    password = getattr(settings, 'CAMPAY_PASSWORD', '')

    if not username or not password:
        return None

    try:
        response = requests.post(
            f'{base_url}/api/token/',
            json={'username': username, 'password': password},
            timeout=15,
        )
        if response.status_code == 200:
            return response.json().get('token')
    except requests.RequestException as e:
        logger.warning(f'CamPay token error: {e}')
    return None


def _initiate_campay_collection(payment):
    """Initiate a mobile money collection via CamPay."""
    base_url = getattr(settings, 'CAMPAY_BASE_URL', 'https://demo.campay.net')
    webhook_url = getattr(settings, 'CAMPAY_WEBHOOK_URL', '')

    token = _get_campay_token()
    if not token:
        return {
            'configured': False,
            'message': 'CamPay credentials not configured. Add CAMPAY_USERNAME and CAMPAY_PASSWORD to your .env file.',
        }

    # Clean phone number - CamPay expects format like 237XXXXXXXXX
    phone = (payment.payer_phone or '').strip()
    phone = phone.replace('+', '').replace(' ', '').replace('-', '')
    if not phone.startswith('237'):
        phone = '237' + phone.lstrip('0')

    headers = {
        'Authorization': f'Token {token}',
        'Content-Type': 'application/json',
    }
    payload = {
        'amount': str(int(payment.amount)),  # CamPay expects integer string
        'currency': 'XAF',
        'from': phone,
        'description': f'Clinix consultation payment - {payment.transaction_ref}',
        'external_reference': payment.transaction_ref,
    }
    if webhook_url:
        payload['webhook_url'] = webhook_url

    try:
        response = requests.post(
            f'{base_url}/api/collect/',
            headers=headers,
            json=payload,
            timeout=30,
        )
        data = response.json() if response.status_code in (200, 201) else {}
        logger.info(f'CamPay collect response: {response.status_code} {data}')

        if response.status_code in (200, 201) and data.get('reference'):
            payment.external_transaction_id = data['reference']
            payment.save(update_fields=['external_transaction_id'])
            return {
                'configured': True,
                'submitted': True,
                'reference': data['reference'],
                'ussd_code': data.get('ussd_code', ''),
                'operator': data.get('operator', ''),
            }
        return {
            'configured': True,
            'submitted': False,
            'gateway_response': data.get('message', response.text),
        }
    except requests.RequestException as exc:
        logger.error(f'CamPay request error: {exc}')
        return {
            'configured': True,
            'submitted': False,
            'gateway_response': str(exc),
        }


def _check_campay_status(reference):
    """Check payment status on CamPay."""
    base_url = getattr(settings, 'CAMPAY_BASE_URL', 'https://demo.campay.net')
    token = _get_campay_token()
    if not token:
        return None

    try:
        response = requests.post(
            f'{base_url}/api/transaction/{reference}/',
            headers={'Authorization': f'Token {token}', 'Content-Type': 'application/json'},
            json={'reference': reference},
            timeout=15,
        )
        if response.status_code == 200:
            return response.json()
    except requests.RequestException:
        pass
    return None


# ─── Views ─────────────────────────────────────────────────────────────────────

class SystemSettingsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        setting, _ = PlatformSetting.objects.get_or_create(id=1)
        return setting

    def get(self, request):
        return Response(PlatformSettingSerializer(self.get_object()).data)

    def patch(self, request):
        if request.user.user_type != 'admin' and not request.user.is_staff:
            return Response({'error': 'Only administrators can update system settings.'}, status=status.HTTP_403_FORBIDDEN)
        setting = self.get_object()
        serializer = PlatformSettingSerializer(setting, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class PaymentInitiateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = PaymentSerializer(data=request.data)
        if serializer.is_valid():
            appointment = serializer.validated_data.get('appointment')
            if not appointment:
                return Response({'error': 'appointment is required'}, status=status.HTTP_400_BAD_REQUEST)

            amount = serializer.validated_data['amount']
            payment_method = serializer.validated_data['payment_method']
            payer_phone = serializer.validated_data.get('payer_phone')

            # No platform fee — provider receives the full consultation fee
            platform_fee = decimal.Decimal('0.00')
            provider_payout = decimal.Decimal(amount)

            try:
                patient = Patient.objects.get(patient_id=request.user)
            except Patient.DoesNotExist:
                return Response({'error': 'Only patients can initiate payments'}, status=status.HTTP_403_FORBIDDEN)

            with transaction.atomic():
                payment = Payment.objects.create(
                    appointment=appointment,
                    patient=patient,
                    provider=appointment.provider if appointment else None,
                    amount=amount,
                    payment_method=payment_method,
                    transaction_ref=f"TXN-{uuid.uuid4().hex[:8].upper()}",
                    payer_phone=payer_phone,
                    platform_fee=platform_fee,
                    provider_payout=provider_payout,
                    status='pending',
                )

            # Use CamPay for both MTN and Orange Money
            gateway_meta = _initiate_campay_collection(payment)

            response_data = PaymentSerializer(payment).data
            response_data['gateway'] = gateway_meta
            return Response(response_data, status=status.HTTP_202_ACCEPTED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CamPayWebhookView(APIView):
    """Receives payment status callbacks from CamPay."""
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def post(self, request):
        reference = request.data.get('reference') or request.data.get('external_reference')
        status_val = request.data.get('status', '').upper()
        logger.info(f'CamPay webhook: ref={reference} status={status_val} data={request.data}')

        if not reference:
            return Response({'error': 'missing reference'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            payment = Payment.objects.get(
                Q(external_transaction_id=reference) | Q(transaction_ref=reference)
            )
        except Payment.DoesNotExist:
            # Try by external_transaction_id or transaction_ref
            try:
                payment = Payment.objects.filter(external_transaction_id=reference).first()
                if not payment:
                    payment = Payment.objects.filter(transaction_ref=reference).first()
                if not payment:
                    return Response({'error': 'payment not found'}, status=status.HTTP_404_NOT_FOUND)
            except Exception:
                return Response({'error': 'payment not found'}, status=status.HTTP_404_NOT_FOUND)

        if status_val == 'SUCCESSFUL' and payment.status != 'success':
            _mark_payment_success(payment)
        elif status_val == 'FAILED':
            payment.status = 'failed'
            payment.save(update_fields=['status'])

        return Response({'status': 'ok'})

    def get(self, request):
        # CamPay sometimes sends GET for verification
        return Response({'status': 'ok'})


class PaymentStatusView(generics.RetrieveAPIView):
    serializer_class = PaymentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.user_type == 'patient':
            return Payment.objects.filter(patient__patient_id=user)
        elif user.user_type == 'provider':
            return Payment.objects.filter(provider__provider_id=user)
        return Payment.objects.none()

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        # If still pending, check CamPay for latest status
        if instance.status == 'pending' and instance.external_transaction_id:
            campay_data = _check_campay_status(instance.external_transaction_id)
            if campay_data:
                campay_status = campay_data.get('status', '').upper()
                if campay_status == 'SUCCESSFUL' and instance.status != 'success':
                    _mark_payment_success(instance)
                    instance.refresh_from_db()
                elif campay_status == 'FAILED':
                    instance.status = 'failed'
                    instance.save(update_fields=['status'])
        return Response(PaymentSerializer(instance).data)


class PaymentHistoryView(generics.ListAPIView):
    serializer_class = PaymentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.user_type == 'patient':
            return Payment.objects.filter(patient__patient_id=user).order_by('-initiated_at')
        elif user.user_type == 'provider':
            return Payment.objects.filter(provider__provider_id=user).order_by('-initiated_at')
        return Payment.objects.filter(patient__patient_id=user).order_by('-initiated_at')


class PaymentDetailView(generics.RetrieveAPIView):
    serializer_class = PaymentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.user_type == 'patient':
            return Payment.objects.filter(patient__patient_id=user)
        elif user.user_type == 'provider':
            return Payment.objects.filter(provider__provider_id=user)
        return Payment.objects.none()


class SubscriptionPaymentView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        return Response({'status': 'Subscription active'})
