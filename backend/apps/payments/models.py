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
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    initiated_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    platform_fee = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    provider_payout = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

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

    class Meta:
        db_table = 'provider_subscriptions'
