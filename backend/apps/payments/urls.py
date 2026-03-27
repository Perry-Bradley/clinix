from django.urls import path
from .views import (
    PaymentInitiateView, MTNMoMoWebhookView, OrangeMoneyWebhookView,
    PaymentHistoryView, PaymentDetailView, SubscriptionPaymentView
)

urlpatterns = [
    path('initiate/', PaymentInitiateView.as_view(), name='payment_initiate'),
    path('mtn/callback/', MTNMoMoWebhookView.as_view(), name='mtn_callback'),
    path('orange/callback/', OrangeMoneyWebhookView.as_view(), name='orange_callback'),
    path('history/', PaymentHistoryView.as_view(), name='payment_history'),
    path('<uuid:pk>/', PaymentDetailView.as_view(), name='payment_detail'),
    path('subscription/', SubscriptionPaymentView.as_view(), name='subscription_payment'),
]
