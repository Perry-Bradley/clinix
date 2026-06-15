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

def _send_via_brevo(to_email, subject, text):
    """Send through the Brevo (Sendinblue) HTTP API (port 443). Brevo allows
    'single sender verification' — you confirm one sender email by clicking a
    link, NO DNS needed — and can then email any recipient. Returns True on
    success, False if not configured or the call failed."""
    import requests
    api_key = os.environ.get('BREVO_API_KEY', '').strip()
    if not api_key:
        return False
    raw_from = (os.environ.get('BREVO_FROM', '').strip()
                or settings.DEFAULT_FROM_EMAIL or '')
    # Accept either "email@x" or "Name <email@x>".
    name, addr = 'Clinix', raw_from
    if '<' in raw_from and '>' in raw_from:
        name = raw_from.split('<', 1)[0].strip() or 'Clinix'
        addr = raw_from.split('<', 1)[1].split('>', 1)[0].strip()
    if not addr:
        return False
    try:
        r = requests.post(
            'https://api.brevo.com/v3/smtp/email',
            headers={'api-key': api_key, 'Content-Type': 'application/json',
                     'accept': 'application/json'},
            json={'sender': {'email': addr, 'name': name},
                  'to': [{'email': to_email}], 'subject': subject, 'textContent': text},
            timeout=20,
        )
        if r.status_code in (200, 201, 202):
            print(f"Email sent via Brevo to {to_email}")
            return True
        print(f"Brevo send failed for {to_email}: {r.status_code} {r.text[:300]}")
        return False
    except Exception as e:
        print(f"Brevo request error for {to_email}: {e}")
        return False


def _send_via_resend(to_email, subject, text):
    """Send through the Resend HTTP API (port 443). Needed because Railway
    blocks outbound SMTP ('Network is unreachable'). Returns True on success,
    False if not configured or the call failed."""
    import requests
    api_key = os.environ.get('RESEND_API_KEY', '').strip()
    if not api_key:
        return False
    from_email = os.environ.get('RESEND_FROM', '').strip() or settings.DEFAULT_FROM_EMAIL
    try:
        r = requests.post(
            'https://api.resend.com/emails',
            headers={'Authorization': f'Bearer {api_key}',
                     'Content-Type': 'application/json'},
            json={'from': from_email, 'to': [to_email], 'subject': subject, 'text': text},
            timeout=20,
        )
        if r.status_code in (200, 201):
            print(f"Email sent via Resend to {to_email}")
            return True
        print(f"Resend send failed for {to_email}: {r.status_code} {r.text[:300]}")
        return False
    except Exception as e:
        print(f"Resend request error for {to_email}: {e}")
        return False


def send_email_otp(email, otp, purpose='verification'):
    """Send an OTP email. Returns True on success so callers can surface a
    real error instead of telling the user 'sent' when nothing went out.

    Prefers the Resend HTTP API (SMTP is blocked on Railway); falls back to
    Django SMTP where outbound SMTP is allowed."""
    subject = f"Your Clinix {purpose} code"
    message = (
        f"Hello,\n\n"
        f"Your Clinix {purpose} code is: {otp}\n\n"
        f"This code expires in 10 minutes.\n\n"
        f"If you did not request this, please ignore this email.\n\n"
        f"— The Clinix Team"
    )

    # 1) HTTP email APIs (work on Railway, which blocks outbound SMTP). Brevo
    #    first (no-DNS single-sender verification), then Resend.
    if _send_via_brevo(email, subject, message):
        return True
    if _send_via_resend(email, subject, message):
        return True

    # 2) Fall back to SMTP where it's reachable.
    try:
        send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [email], fail_silently=False)
        print(f"Email OTP sent to {email}")
        return True
    except Exception as e:
        print(f"EMAIL OTP SEND FAILED for {email}: {otp} (error: {e})")
        return False


def send_email_otp_async(email, otp, purpose='verification'):
    """Send the OTP email on a background thread so the HTTP request returns
    immediately instead of blocking on (sometimes slow) SMTP — which was
    causing the reset/OTP endpoints to hang until the client timed out."""
    import threading
    threading.Thread(
        target=send_email_otp, args=(email, otp, purpose), daemon=True,
    ).start()
