from django.urls import path
from .views import (
    PaymentInitiateView, CamPayWebhookView,
    PaymentHistoryView, PaymentDetailView, SubscriptionPaymentView, PaymentStatusView
)

urlpatterns = [
    path('initiate/', PaymentInitiateView.as_view(), name='payment_initiate'),
    path('status/<uuid:pk>/', PaymentStatusView.as_view(), name='payment_status'),
    path('campay/webhook/', CamPayWebhookView.as_view(), name='campay_webhook'),
    path('history/', PaymentHistoryView.as_view(), name='payment_history'),
    path('<uuid:pk>/', PaymentDetailView.as_view(), name='payment_detail'),
    path('subscription/', SubscriptionPaymentView.as_view(), name='subscription_payment'),
]
