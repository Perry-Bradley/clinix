from rest_framework import serializers
from .models import Payment, ProviderSubscription
from apps.appointments.serializers import AppointmentSerializer

class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = '__all__'
        read_only_fields = ('payment_id', 'status', 'initiated_at', 'completed_at', 'transaction_ref', 'platform_fee', 'provider_payout')

class ProviderSubscriptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProviderSubscription
        fields = '__all__'
        read_only_fields = ('subscription_id',)
