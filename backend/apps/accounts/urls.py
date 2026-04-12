from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView, TokenBlacklistView
from .views import (
    PatientRegisterView, ProviderRegisterView,
    BasicRegisterView, RoleSelectionView,
    SendOTPView, VerifyOTPView, LoginView,
    SendEmailOTPView, VerifyEmailOTPView,
    FCMTokenView,
    PasswordResetRequestView, PasswordResetConfirmView,
    GoogleAuthView, ProfessionalBioUpdateView
)

urlpatterns = [
    path('register/', BasicRegisterView.as_view(), name='register_basic'),
    path('role-selection/', RoleSelectionView.as_view(), name='role_selection'),
    path('register/patient/', PatientRegisterView.as_view(), name='register_patient'),
    path('register/provider/', ProviderRegisterView.as_view(), name='register_provider'),
    path('otp/send/', SendOTPView.as_view(), name='send_otp'),
    path('otp/verify/', VerifyOTPView.as_view(), name='verify_otp'),
    path('otp/email/send/', SendEmailOTPView.as_view(), name='send_email_otp'),
    path('otp/email/verify/', VerifyEmailOTPView.as_view(), name='verify_email_otp'),
    path('fcm-token/', FCMTokenView.as_view(), name='fcm_token'),
    path('login/', LoginView.as_view(), name='login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('logout/', TokenBlacklistView.as_view(), name='token_blacklist'),
    path('password/reset/', PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('password/confirm/', PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    path('google-auth/', GoogleAuthView.as_view(), name='google_auth'),
    path('provider/bio/', ProfessionalBioUpdateView.as_view(), name='provider_bio_update'),
]
