import firebase_admin
from firebase_admin import credentials, auth
import os
import json
from django.conf import settings

def initialize_firebase():
    """
    Initializes the Firebase Admin SDK.
    Tries env var FIREBASE_ADMIN_CREDENTIALS_JSON first (for production),
    then falls back to firebase_key.json file (for local dev).
    """
    if firebase_admin._apps:
        return

    # Production: credentials from env var (paste whole JSON)
    creds_json = os.environ.get('FIREBASE_ADMIN_CREDENTIALS_JSON')
    if creds_json:
        try:
            cred_dict = json.loads(creds_json)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            print("Firebase Admin initialized from env var.")
            return
        except Exception as e:
            print(f"Failed to parse FIREBASE_ADMIN_CREDENTIALS_JSON: {e}")

    # Dev: credentials from file
    key_path = os.path.join(settings.BASE_DIR, 'firebase_key.json')
    if os.path.exists(key_path):
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
        print("Firebase Admin initialized from firebase_key.json.")
    else:
        print(f"Firebase key not found at {key_path} and no env credentials set. Auth may fail.")

def verify_google_token(id_token):
    """
    Verifies a Google ID token received from the mobile app.
    Returns the decoded token (which includes email, name, etc.) if valid.
    """
    try:
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token
    except Exception as e:
        print(f"Error verifying Firebase token: {e}")
        return None
