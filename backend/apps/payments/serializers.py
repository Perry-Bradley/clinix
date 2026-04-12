from rest_framework import serializers
from .models import Payment, ProviderSubscription, PlatformSetting
from apps.appointments.serializers import AppointmentSerializer

class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = '__all__'
        read_only_fields = ('payment_id', 'status', 'initiated_at', 'completed_at', 'transaction_ref', 'platform_fee', 'provider_payout')

    def validate_payment_method(self, value):
        allowed = {'mtn_momo', 'orange_money'}
        if value not in allowed:
            raise serializers.ValidationError('Only MTN MoMo and Orange Money are supported.')
        return value

class ProviderSubscriptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProviderSubscription
        fields = '__all__'
        read_only_fields = ('subscription_id',)

class PlatformSettingSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlatformSetting
        fields = ('consultation_fee', 'service_charge', 'updated_at')
        read_only_fields = ('updated_at',)
