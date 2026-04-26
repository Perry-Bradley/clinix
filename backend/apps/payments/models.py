from django.db import models
from apps.appointments.models import Appointment
from apps.patients.models import Patient
from apps.providers.models import HealthcareProvider
import uuid

class Payment(models.Model):
    PAYMENT_METHOD_CHOICES = (
        ('mtn_momo', 'MTN MoMo'),
        ('orange_money', 'Orange Money'),
        ('cash', 'Cash'),
    )

    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('success', 'Success'),
        ('failed', 'Failed'),
        ('refunded', 'Refunded'),
    )

    payment_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    appointment = models.ForeignKey(Appointment, on_delete=models.CASCADE, related_name='payments', null=True, blank=True)
    patient = models.ForeignKey(Patient, on_delete=models.SET_NULL, null=True, blank=True, related_name='payments')
    provider = models.ForeignKey(HealthcareProvider, on_delete=models.SET_NULL, null=True, blank=True, related_name='payments')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    currency = models.CharField(max_length=3, default='XAF')
    payment_method = models.CharField(max_length=20, choices=PAYMENT_METHOD_CHOICES)
    transaction_ref = models.CharField(max_length=255, unique=True, null=True, blank=True)
    external_transaction_id = models.CharField(max_length=255, null=True, blank=True)
    payer_phone = models.CharField(max_length=20, null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    initiated_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    platform_fee = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    provider_payout = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    # Booking data held during a "pay-first" service flow (lab tests / home
    # treatments). When the Campay charge succeeds we materialise the
    # Appointment from this payload — the patient never has a phantom pending
    # appointment hanging around if they abandon checkout.
    # Shape: {provider_id, scheduled_at, appointment_type, address,
    #         service_name, duration_minutes}
    pending_booking = models.JSONField(blank=True, null=True)

    class Meta:
        db_table = 'payments'

class ProviderSubscription(models.Model):
    PLAN_CHOICES = (
        ('basic', 'Basic'),
        ('professional', 'Professional'),
        ('premium', 'Premium'),
    )

    subscription_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider = models.ForeignKey(HealthcareProvider, on_delete=models.CASCADE, related_name='subscriptions')
    plan_type = models.CharField(max_length=20, choices=PLAN_CHOICES)
    amount_paid = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    payment = models.ForeignKey(Payment, on_delete=models.SET_NULL, null=True, blank=True)
    starts_at = models.DateTimeField()
    expires_at = models.DateTimeField()
    is_active = models.BooleanField(default=True)

class PlatformSetting(models.Model):
    consultation_fee = models.IntegerField(default=15000)
    service_charge = models.IntegerField(default=500)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'platform_settings'
        verbose_name_plural = 'Platform Settings'

    def __str__(self):
        return f"Global Fee: {self.consultation_fee} XAF"

class ProviderWallet(models.Model):
    provider = models.OneToOneField(HealthcareProvider, on_delete=models.CASCADE, related_name='wallet')
    balance = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Wallet: {self.provider} - Balance: {self.balance} XAF"

class WalletTransaction(models.Model):
    TX_TYPES = (
        ('credit', 'Credit (Consultation)'),
        ('debit', 'Debit (Withdrawal)'),
        ('refund', 'Refund'),
    )
    wallet = models.ForeignKey(ProviderWallet, on_delete=models.CASCADE, related_name='transactions')
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    transaction_type = models.CharField(max_length=20, choices=TX_TYPES)
    reference = models.CharField(max_length=100, blank=True, null=True) 
    created_at = models.DateTimeField(auto_now_add=True)

class WithdrawalRequest(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending Authentication'),
        ('approved', 'Approved'),
        ('completed', 'Completed'),
        ('rejected', 'Rejected'),
    )
    provider = models.ForeignKey(HealthcareProvider, on_delete=models.CASCADE, related_name='payout_requests')
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    payout_method = models.CharField(max_length=50, default='mtn_momo')
    payout_details = models.CharField(max_length=255) 
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    requested_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    admin_notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ['-requested_at']
