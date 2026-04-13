from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated
import firebase_admin
from firebase_admin import auth as firebase_auth
from django.conf import settings
from apps.providers.models import HealthcareProvider
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from .models import User
from .serializers import (
    PatientRegisterSerializer, ProviderRegisterSerializer,
    OTPSendSerializer, OTPVerifySerializer, PasswordResetConfirmSerializer,
    EmailOTPSendSerializer, EmailOTPVerifySerializer, FCMTokenSerializer,
    BasicRegisterSerializer, RoleSelectionSerializer
)
from .utils import (
    generate_otp, set_otp, verify_otp, send_sms,
    set_email_otp, verify_email_otp, send_email_otp
)
from apps.patients.models import Patient

def get_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
        'user_type': user.user_type,
        'user_id': str(user.user_id),
        'full_name': user.full_name,
    }

# ─── Registration ─────────────────────────────────────────────────────────────

class BasicRegisterView(generics.CreateAPIView):
    serializer_class = BasicRegisterSerializer
    permission_classes = (AllowAny,)
    
    def perform_create(self, serializer):
        user = serializer.save()
        return user

class RoleSelectionView(APIView):
    permission_classes = (IsAuthenticated,)

    def post(self, request):
        serializer = RoleSelectionSerializer(data=request.data)
        if serializer.is_valid():
            user_type = serializer.validated_data['user_type']
            user = request.user
            
            # Allow setting the same role again (idempotent)
            if user.user_type != 'unassigned' and user.user_type != user_type:
                return Response({'error': f'Role already assigned as {user.user_type}'}, status=status.HTTP_400_BAD_REQUEST)
            
            if user.user_type == 'unassigned':
                user.user_type = user_type
                user.save()
            
            if user_type == 'patient':
                Patient.objects.get_or_create(patient_id=user)
            elif user_type == 'provider':
                HealthcareProvider.objects.get_or_create(
                    provider_id=user,
                    defaults={'license_number': f'pending_{user.user_id}'}
                )
                
            return Response({'message': f'Role set to {user_type}', 'user_type': user_type})
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class PatientRegisterView(generics.CreateAPIView):
    serializer_class = PatientRegisterSerializer
    permission_classes = (AllowAny,)
    
    def perform_create(self, serializer):
        user = serializer.save()
        otp = generate_otp()
        if user.email:
            set_email_otp(user.email, otp)
            send_email_otp(user.email, otp)
        if user.phone_number:
            set_otp(user.phone_number, otp)
            send_sms(user.phone_number, f"Your Clinix verification code is {otp}")

class ProviderRegisterView(generics.CreateAPIView):
    serializer_class = ProviderRegisterSerializer
    permission_classes = (AllowAny,)
    
    def perform_create(self, serializer):
        user = serializer.save()
        otp = generate_otp()
        if user.email:
            set_email_otp(user.email, otp)
            send_email_otp(user.email, otp)
        if user.phone_number:
            set_otp(user.phone_number, otp)
            send_sms(user.phone_number, f"Your Clinix verification code is {otp}")

# ─── Phone OTP ────────────────────────────────────────────────────────────────

class SendOTPView(APIView):
    permission_classes = (AllowAny,)
    
    def post(self, request):
        serializer = OTPSendSerializer(data=request.data)
        if serializer.is_valid():
            phone_number = serializer.validated_data['phone_number']
            if User.objects.filter(phone_number=phone_number).exists():
                otp = generate_otp()
                set_otp(phone_number, otp)
                send_sms(phone_number, f"Your Clinix login code is {otp}")
                return Response({'message': 'OTP sent successfully'})
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class VerifyOTPView(APIView):
    permission_classes = (AllowAny,)
    
    def post(self, request):
        serializer = OTPVerifySerializer(data=request.data)
        if serializer.is_valid():
            phone_number = serializer.validated_data['phone_number']
            otp = serializer.validated_data['otp']
            if verify_otp(phone_number, otp):
                try:
                    user = User.objects.get(phone_number=phone_number)
                    if not user.is_verified:
                        user.is_verified = True
                        user.save()
                    tokens = get_tokens_for_user(user)
                    return Response(tokens)
                except User.DoesNotExist:
                    return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
            return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

# ─── Email OTP ────────────────────────────────────────────────────────────────

class SendEmailOTPView(APIView):
    permission_classes = (AllowAny,)
    
    def post(self, request):
        serializer = EmailOTPSendSerializer(data=request.data)
        if serializer.is_valid():
            email = serializer.validated_data['email']
            if User.objects.filter(email=email).exists():
                otp = generate_otp()
                set_email_otp(email, otp)
                send_email_otp(email, otp)
                return Response({'message': 'OTP sent to email'})
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class VerifyEmailOTPView(APIView):
    permission_classes = (AllowAny,)
    
    def post(self, request):
        serializer = EmailOTPVerifySerializer(data=request.data)
        if serializer.is_valid():
            email = serializer.validated_data['email']
            otp = serializer.validated_data['otp']
            if verify_email_otp(email, otp):
                try:
                    user = User.objects.get(email=email)
                    if not user.is_verified:
                        user.is_verified = True
                        user.save()
                    tokens = get_tokens_for_user(user)
                    return Response(tokens)
                except User.DoesNotExist:
                    return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
            return Response({'error': 'Invalid or expired OTP'}, status=status.HTTP_400_BAD_REQUEST)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

# ─── Login ───────────────────────────────────────────────────────────────────

class LoginView(APIView):
    permission_classes = (AllowAny,)
    
    def post(self, request):
        identifier = request.data.get('identifier')
        password = request.data.get('password')

        user = None
        if not identifier or not password:
             return Response({'error': 'Identifier and password required'}, status=status.HTTP_400_BAD_REQUEST)

        if '@' in identifier:
            user = authenticate(username=identifier, password=password)
        else:
            try:
                u = User.objects.get(phone_number=identifier)
                user = authenticate(username=u.email, password=password)
            except User.DoesNotExist:
                pass
        
        if user:
            tokens = get_tokens_for_user(user)
            return Response(tokens)
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)

# ─── FCM Token ───────────────────────────────────────────────────────────────

class FCMTokenView(APIView):
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        serializer = FCMTokenSerializer(data=request.data)
        if serializer.is_valid():
            request.user.fcm_token = serializer.validated_data['fcm_token']
            request.user.save()
            return Response({'message': 'FCM token saved'})
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

# ─── Password Reset ───────────────────────────────────────────────────────────

class PasswordResetRequestView(APIView):
    permission_classes = (AllowAny,)
    
    def post(self, request):
        serializer = OTPSendSerializer(data=request.data)
        if serializer.is_valid():
            phone_number = serializer.validated_data['phone_number']
            if User.objects.filter(phone_number=phone_number).exists():
                otp = generate_otp()
                set_otp(phone_number, otp)
                send_sms(phone_number, f"Your Clinix password reset code is {otp}")
                return Response({'message': 'OTP sent'})
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class PasswordResetConfirmView(APIView):
    permission_classes = (AllowAny,)
    
    def patch(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        if serializer.is_valid():
            phone_number = serializer.validated_data['phone_number']
            otp = serializer.validated_data['otp']
            new_password = serializer.validated_data['new_password']
            
            if verify_otp(phone_number, otp):
                user = User.objects.get(phone_number=phone_number)
                user.set_password(new_password)
                user.save()
                return Response({'message': 'Password reset successful'})
            return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

# ─── OAuth ───────────────────────────────────────────────────────────────────

class GoogleAuthView(APIView):
    permission_classes = (AllowAny,)

    def post(self, request):
        id_token = request.data.get('id_token')
        
        if not id_token:
            return Response({'error': 'ID token is required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            decoded_token = firebase_auth.verify_id_token(id_token)
            email = decoded_token.get('email')
            name = decoded_token.get('name', '')
            uid = decoded_token.get('uid')
            
            if not email:
                return Response({'error': 'Email not found in token'}, status=status.HTTP_400_BAD_REQUEST)

            user, created = User.objects.get_or_create(
                email=email,
                defaults={
                    'full_name': name,
                    'user_type': 'unassigned',
                    'is_verified': True,
                    'phone_number': f"google_{uid[:13]}"
                }
            )

            if created:
                user.set_unusable_password()
                user.save()
            
            tokens = get_tokens_for_user(user)
            return Response(tokens)

        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_401_UNAUTHORIZED)

# ─── Provider Utilities ───────────────────────────────────────────────────────

class ProfessionalBioUpdateView(APIView):
    permission_classes = (IsAuthenticated,)

    def patch(self, request):
        if request.user.user_type != 'provider':
            return Response({'error': 'Only providers can update bio'}, status=status.HTTP_403_FORBIDDEN)
        
        try:
            provider = HealthcareProvider.objects.get(provider_id=request.user)
            bio = request.data.get('bio')
            fee = request.data.get('consultation_fee')
            
            if bio:
                provider.bio = bio
            if fee is not None:
                provider.consultation_fee = fee
                
            provider.save()
            return Response({'message': 'Profile updated successfully'})
        except HealthcareProvider.DoesNotExist:
            return Response({'error': 'Provider profile not found'}, status=status.HTTP_404_NOT_FOUND)
