from django.conf import settings
from twilio.rest import Client
import redis
import random
import environ

env = environ.Env()

redis_client = redis.from_url(env('REDIS_URL', default='redis://127.0.0.1:6379/0'))

def generate_otp():
    return str(random.randint(100000, 999999))

def set_otp(phone_number, otp):
    key = f"otp:{phone_number}"
    redis_client.set(key, otp, ex=600) # 10 minutes TTL

def get_otp(phone_number):
    key = f"otp:{phone_number}"
    otp_bytes = redis_client.get(key)
    if otp_bytes:
        return otp_bytes.decode('utf-8')
    return None

def verify_otp(phone_number, submitted_otp):
    key = f"otp:{phone_number}"
    stored_otp = get_otp(phone_number)
    if stored_otp and stored_otp == submitted_otp:
        redis_client.delete(key)
        return True
    return False

def send_sms(to_number, body):
    account_sid = env('TWILIO_ACCOUNT_SID', default=None)
    auth_token = env('TWILIO_AUTH_TOKEN', default=None)
    from_number = env('TWILIO_PHONE_NUMBER', default=None)
    
    if account_sid and auth_token and from_number:
        try:
            client = Client(account_sid, auth_token)
            message = client.messages.create(
                body=body,
                from_=from_number,
                to=to_number
            )
            return message.sid
        except Exception as e:
            print(f"Twilio error: {e}")
            return None
    else:
        # Mock SMS sending if twilio is not configured
        print(f"MOCK SMS to {to_number}: {body}")
        return "mock_sid_123"
