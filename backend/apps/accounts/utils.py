from django.conf import settings
from django.core.mail import send_mail
from twilio.rest import Client
from django.core.cache import cache
import random
import os

def generate_otp():
    return str(random.randint(100000, 999999))

# ─── Phone OTP (Twilio) ─────────────────────────────────────────────────────

def set_otp(phone_number, otp):
    key = f"otp:{phone_number}"
    cache.set(key, otp, timeout=600)

def get_otp(phone_number):
    key = f"otp:{phone_number}"
    return cache.get(key)

def verify_otp(phone_number, submitted_otp):
    key = f"otp:{phone_number}"
    stored_otp = get_otp(phone_number)
    if stored_otp and str(stored_otp) == str(submitted_otp):
        cache.delete(key)
        return True
    return False

def send_sms(to_number, body):
    # Use settings to get env values if possible, or use os.environ
    account_sid = os.environ.get('TWILIO_ACCOUNT_SID')
    auth_token = os.environ.get('TWILIO_AUTH_TOKEN')
    from_number = os.environ.get('TWILIO_PHONE_NUMBER')
    
    if account_sid and auth_token and from_number:
        try:
            client = Client(account_sid, auth_token)
            message = client.messages.create(body=body, from_=from_number, to=to_number)
            return message.sid
        except Exception as e:
            print(f"Twilio error: {e}")
            return None
    else:
        print(f"MOCK SMS to {to_number}: {body}")
        return "mock_sid_123"

# ─── Email OTP ───────────────────────────────────────────────────────────────

def set_email_otp(email, otp):
    key = f"email_otp:{email}"
    cache.set(key, otp, timeout=600)  # 10 minutes TTL

def get_email_otp(email):
    key = f"email_otp:{email}"
    return cache.get(key)

def verify_email_otp(email, submitted_otp):
    key = f"email_otp:{email}"
    stored_otp = get_email_otp(email)
    if stored_otp and str(stored_otp) == str(submitted_otp):
        cache.delete(key)
        return True
    return False

def send_email_otp(email, otp):
    subject = "Your Clinix Verification Code"
    message = (
        f"Hello,\n\n"
        f"Your Clinix verification code is: {otp}\n\n"
        f"This code expires in 10 minutes.\n\n"
        f"If you did not request this, please ignore this email.\n\n"
        f"— The Clinix Team"
    )
    from_email = settings.DEFAULT_FROM_EMAIL
    try:
        send_mail(subject, message, from_email, [email], fail_silently=False)
        print(f"Email OTP sent to {email}")
    except Exception as e:
        # In development without email configured, just print it
        print(f"MOCK EMAIL OTP to {email}: {otp} (error: {e})")
