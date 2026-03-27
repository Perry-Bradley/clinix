from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from .models import Payment, ProviderSubscription
from .serializers import PaymentSerializer
from apps.appointments.models import Appointment
from apps.patients.models import Patient
import uuid
import decimal

class PaymentInitiateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = PaymentSerializer(data=request.data)
        if serializer.is_valid():
            appointment = serializer.validated_data.get('appointment')
            amount = serializer.validated_data['amount']
            payment_method = serializer.validated_data['payment_method']
            
            # 10% platform fee
            platform_fee = decimal.Decimal(amount) * decimal.Decimal('0.10')
            provider_payout = decimal.Decimal(amount) - platform_fee
            
            try:
                patient = Patient.objects.get(patient_id=request.user)
            except Patient.DoesNotExist:
                return Response({'error': 'Only patients can initiate appointment payments'}, status=status.HTTP_403_FORBIDDEN)
                
            payment = Payment.objects.create(
                appointment=appointment,
                patient=patient,
                provider=appointment.provider if appointment else None,
                amount=amount,
                payment_method=payment_method,
                transaction_ref=f"TXN-{uuid.uuid4().hex[:8].upper()}",
                platform_fee=platform_fee,
                provider_payout=provider_payout
            )
            
            # Here we would call external MTN/Orange payment APIs
            # For now, we mock success and return the Payment info
            
            return Response(PaymentSerializer(payment).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class MTNMoMoWebhookView(APIView):
    permission_classes = [permissions.AllowAny] # Usually requires IP whitelist / signature
    
    def post(self, request):
        # Handle MTN MoMo callbacks
        tx_ref = request.data.get('transaction_ref')
        status_val = request.data.get('status')
        try:
            payment = Payment.objects.get(transaction_ref=tx_ref)
            payment.status = status_val.lower()
            if status_val.lower() == 'success':
                payment.completed_at = timezone.now()
                if payment.appointment:
                    payment.appointment.status = 'confirmed'
                    payment.appointment.save()
            payment.save()
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
            payment.status = status_val.lower()
            if status_val.lower() == 'success':
                payment.completed_at = timezone.now()
                if payment.appointment:
                    payment.appointment.status = 'confirmed'
                    payment.appointment.save()
            payment.save()
            return Response({'status': 'ok'})
        except Payment.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

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
