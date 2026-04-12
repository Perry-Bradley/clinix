from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Payment, ProviderWallet, WalletTransaction

@receiver(post_save, sender=Payment)
def credit_provider_wallet(sender, instance, created, **kwargs):
    """
    Credit the provider wallet when a payment is marked as success.
    """
    if instance.status == 'success' and instance.provider:
        # Get or create wallet for the provider
        wallet, _ = ProviderWallet.objects.get_or_create(provider=instance.provider)
        
        # Check if this payment was already credited (avoid double credit)
        if not WalletTransaction.objects.filter(wallet=wallet, reference=str(instance.payment_id)).exists():
            amount_to_credit = instance.provider_payout or 0.00
            
            if amount_to_credit > 0:
                wallet.balance += amount_to_credit
                wallet.save()
                
                # Log transaction
                WalletTransaction.objects.create(
                    wallet=wallet,
                    amount=amount_to_credit,
                    transaction_type='credit',
                    reference=str(instance.payment_id)
                )
