from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView, TokenBlacklistView
from .views import (
    PatientRegisterView, ProviderRegisterView,
    SendOTPView, VerifyOTPView, LoginView,
    PasswordResetRequestView, PasswordResetConfirmView
)

urlpatterns = [
    path('register/patient/', PatientRegisterView.as_view(), name='register_patient'),
    path('register/provider/', ProviderRegisterView.as_view(), name='register_provider'),
    path('otp/send/', SendOTPView.as_view(), name='send_otp'),
    path('otp/verify/', VerifyOTPView.as_view(), name='verify_otp'),
    path('login/', LoginView.as_view(), name='login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('logout/', TokenBlacklistView.as_view(), name='token_blacklist'),
    path('password/reset/', PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('password/confirm/', PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
]
