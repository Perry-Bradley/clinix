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

    Also configures the default Storage bucket (needed for the AI-scribe
    flow that uploads call audio for Google Speech-to-Text). The bucket
    name comes from FIREBASE_STORAGE_BUCKET, with a sensible fallback
    derived from the credentials' project_id.
    """
    if firebase_admin._apps:
        return

    def _bucket_name(project_id: str | None) -> str | None:
        explicit = os.environ.get('FIREBASE_STORAGE_BUCKET')
        if explicit:
            return explicit
        if project_id:
            # New Firebase projects use *.firebasestorage.app, older ones
            # *.appspot.com. We default to .appspot.com (more common) and
            # let admins override with the env var if it differs.
            return f'{project_id}.appspot.com'
        return None

    # Production: credentials from env var (paste whole JSON)
    creds_json = os.environ.get('FIREBASE_ADMIN_CREDENTIALS_JSON')
    if creds_json:
        try:
            cred_dict = json.loads(creds_json)
            cred = credentials.Certificate(cred_dict)
            options = {}
            bucket = _bucket_name(cred_dict.get('project_id'))
            if bucket:
                options['storageBucket'] = bucket
            firebase_admin.initialize_app(cred, options or None)
            print(f"Firebase Admin initialized from env var (bucket={bucket}).")
            return
        except Exception as e:
            print(f"Failed to parse FIREBASE_ADMIN_CREDENTIALS_JSON: {e}")

    # Dev: credentials from file
    key_path = os.path.join(settings.BASE_DIR, 'firebase_key.json')
    if os.path.exists(key_path):
        cred = credentials.Certificate(key_path)
        try:
            with open(key_path) as f:
                pid = json.load(f).get('project_id')
        except Exception:
            pid = None
        options = {}
        bucket = _bucket_name(pid)
        if bucket:
            options['storageBucket'] = bucket
        firebase_admin.initialize_app(cred, options or None)
        print(f"Firebase Admin initialized from firebase_key.json (bucket={bucket}).")
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
