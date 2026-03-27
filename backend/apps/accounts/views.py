from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from .models import User
from .serializers import (
    PatientRegisterSerializer, ProviderRegisterSerializer,
    OTPSendSerializer, OTPVerifySerializer, PasswordResetConfirmSerializer
)
from .utils import generate_otp, set_otp, verify_otp, send_sms

def get_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }

class PatientRegisterView(generics.CreateAPIView):
    serializer_class = PatientRegisterSerializer
    permission_classes = (AllowAny,)
    
    def perform_create(self, serializer):
        user = serializer.save()
        # Auto-send OTP on registration
        otp = generate_otp()
        set_otp(user.phone_number, otp)
        send_sms(user.phone_number, f"Your Clinix verification code is {otp}")

class ProviderRegisterView(generics.CreateAPIView):
    serializer_class = ProviderRegisterSerializer
    permission_classes = (AllowAny,)
    
    def perform_create(self, serializer):
        user = serializer.save()
        otp = generate_otp()
        set_otp(user.phone_number, otp)
        send_sms(user.phone_number, f"Your Clinix verification code is {otp}")

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

class LoginView(APIView):
    permission_classes = (AllowAny,)
    
    def post(self, request):
        phone_number = request.data.get('phone_number')
        password = request.data.get('password')
        if not phone_number or not password:
            return Response({'error': 'Please provide both phone_number and password'}, status=status.HTTP_400_BAD_REQUEST)
            
        user = authenticate(phone_number=phone_number, password=password)
        if user:
            tokens = get_tokens_for_user(user)
            return Response(tokens)
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)

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
