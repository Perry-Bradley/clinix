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
from django.db import transaction
import requests


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
    return payment


def _initiate_mtn_collection(payment):
    base_url = getattr(settings, 'MTN_MOMO_BASE_URL', '')
    subscription_key = getattr(settings, 'MTN_MOMO_SUBSCRIPTION_KEY', '')
    api_user = getattr(settings, 'MTN_MOMO_API_USER', '')
    api_key = getattr(settings, 'MTN_MOMO_API_KEY', '')
    target_environment = getattr(settings, 'MTN_MOMO_TARGET_ENVIRONMENT', 'sandbox')
    callback_url = getattr(settings, 'MTN_MOMO_CALLBACK_URL', '')
    payee_phone = getattr(settings, 'CLINIX_MTN_COLLECTION_PHONE', '+237670253822')

    if not all([base_url, subscription_key, api_user, api_key, callback_url]):
        return {
            'configured': False,
            'message': 'MTN MoMo credentials are not configured. Payment remains pending until gateway setup is completed.',
            'payee_phone': payee_phone,
        }

    reference_id = str(uuid.uuid4())
    headers = {
        'X-Reference-Id': reference_id,
        'X-Target-Environment': target_environment,
        'Ocp-Apim-Subscription-Key': subscription_key,
        'Content-Type': 'application/json',
    }
    payload = {
        'amount': str(payment.amount),
        'currency': payment.currency,
        'externalId': payment.transaction_ref,
        'payer': {
            'partyIdType': 'MSISDN',
            'partyId': payment.payer_phone,
        },
        'payerMessage': 'Clinix consultation payment',
        'payeeNote': f'Clinix collection for {payee_phone}',
    }

    try:
        response = requests.post(
            f'{base_url.rstrip('/')}/collection/v1_0/requesttopay',
            headers=headers,
            json=payload,
            timeout=20,
            auth=(api_user, api_key),
        )
        if response.status_code in (200, 201, 202):
            payment.external_transaction_id = reference_id
            payment.save(update_fields=['external_transaction_id'])
            return {
                'configured': True,
                'submitted': True,
                'reference_id': reference_id,
                'payee_phone': payee_phone,
            }
        return {
            'configured': True,
            'submitted': False,
            'reference_id': reference_id,
            'gateway_response': response.text,
            'payee_phone': payee_phone,
        }
    except requests.RequestException as exc:
        return {
            'configured': True,
            'submitted': False,
            'reference_id': reference_id,
            'gateway_response': str(exc),
            'payee_phone': payee_phone,
        }

class SystemSettingsView(APIView):
    """
    Handles retrieval and updating of global platform settings (fees).
    GET: Available to all authenticated users (Patients for checkout, Admins for viewing).
    PATCH: Available to Admins only.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        setting, created = PlatformSetting.objects.get_or_create(id=1)
        return setting

    def get(self, request):
        setting = self.get_object()
        serializer = PlatformSettingSerializer(setting)
        return Response(serializer.data)

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
            
            # 10% platform fee
            platform_fee = decimal.Decimal(amount) * decimal.Decimal('0.10')
            provider_payout = decimal.Decimal(amount) - platform_fee
            
            try:
                patient = Patient.objects.get(patient_id=request.user)
            except Patient.DoesNotExist:
                return Response({'error': 'Only patients can initiate appointment payments'}, status=status.HTTP_403_FORBIDDEN)
                
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

            gateway_meta = {}
            if payment_method == 'mtn_momo':
                gateway_meta = _initiate_mtn_collection(payment)
            elif payment_method == 'orange_money':
                gateway_meta = {
                    'configured': False,
                    'message': 'Orange Money live gateway is not configured yet. Payment remains pending.',
                }

            response_data = PaymentSerializer(payment).data
            response_data['gateway'] = gateway_meta
            response_data['message'] = 'Payment request created. Await gateway confirmation before appointment is confirmed.'
            return Response(response_data, status=status.HTTP_202_ACCEPTED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class MTNMoMoWebhookView(APIView):
    permission_classes = [permissions.AllowAny] # Usually requires IP whitelist / signature
    
    def post(self, request):
        # Handle MTN MoMo callbacks
        tx_ref = request.data.get('transaction_ref') or request.data.get('externalId')
        status_val = request.data.get('status')
        try:
            payment = Payment.objects.get(transaction_ref=tx_ref)
            if status_val.lower() == 'success' and payment.status != 'success':
                _mark_payment_success(payment)
            elif status_val:
                payment.status = status_val.lower()
                payment.save(update_fields=['status'])
            return Response({'status': 'ok'})
        except Payment.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

class OrangeMoneyWebhookView(APIView):
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        # Handle Orange Money callbacks
        tx_ref = request.data.get('transaction_ref')
        status_val = request.data.get('status')
        try:
            payment = Payment.objects.get(transaction_ref=tx_ref)
            if status_val.lower() == 'success' and payment.status != 'success':
                _mark_payment_success(payment)
            elif status_val:
                payment.status = status_val.lower()
                payment.save(update_fields=['status'])
            return Response({'status': 'ok'})
        except Payment.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

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
        # Mocking provider subscription logic
        return Response({'status': 'Subscription active'})
