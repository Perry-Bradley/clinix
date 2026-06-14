import os
from pathlib import Path
from datetime import timedelta
import environ


# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent.parent

env = environ.Env()
environ.Env.read_env(os.path.join(BASE_DIR, '.env'))

SECRET_KEY = env('SECRET_KEY', default='django-insecure-replace-this-in-production')

DEBUG = env.bool('DEBUG', default=False)

ALLOWED_HOSTS = env.list('ALLOWED_HOSTS', default=['*'])

# Deployed behind Railway's TLS proxy: trust X-Forwarded-Proto so
# request.is_secure() is correct and build_absolute_uri() returns https://
# URLs (Android blocks cleartext http, so media links would otherwise
# never load in the app).
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
USE_X_FORWARDED_HOST = True

# Patients attach photos to the AI chat as base64 JSON; a phone photo can
# easily exceed Django's 2.5 MB default request cap, which made image
# messages fail with a 400 while plain text worked.
DATA_UPLOAD_MAX_MEMORY_SIZE = 20 * 1024 * 1024  # 20 MB

# Daphne is required for production ASGI; optional for local migrate/shell if not installed.
try:
    import daphne  # noqa: F401
    _ASGI_INSTALLED = ['daphne']
except ImportError:
    _ASGI_INSTALLED = []

INSTALLED_APPS = _ASGI_INSTALLED + [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.postgres',

    # Third party
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'corsheaders',
    'django_filters',
    'drf_spectacular',

    # Local apps
    'apps.accounts',
    'apps.patients',
    'apps.providers',
    'apps.appointments',
    'apps.consultations',
    'apps.ai_engine',
    'apps.federated_learning',
    'apps.payments',
    'apps.notifications',
    'apps.direct_chat',
    'apps.locations',
    'apps.admin_dashboard',
    'apps.health_metrics',
    'apps.lab_tests',
]

CORS_ALLOW_ALL_ORIGINS = True

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    # WhiteNoise serves /static/* in production so the Django admin keeps its
    # CSS/JS without needing a separate web server. Must come right after
    # SecurityMiddleware per WhiteNoise docs.
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'apps.accounts.middleware.LastSeenMiddleware',
]

ROOT_URLCONF = 'clinix_project.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'clinix_project.wsgi.application'
ASGI_APPLICATION = 'clinix_project.asgi.application'

DATABASES = {
    'default': env.db('DATABASE_URL', default=f"sqlite:///{BASE_DIR / 'db.sqlite3'}")
}
if env('DB_USER', default=None):
    DATABASES['default'] = {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': env('DB_NAME', default='clinix_db'),
        'USER': env('DB_USER', default='clinix_user'),
        'PASSWORD': env('DB_PASSWORD', default=''),
        'HOST': env('DB_HOST', default='db'),
        'PORT': env('DB_PORT', default='5432'),
    }

AUTH_USER_MODEL = 'accounts.User'

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
# WhiteNoise: serve compressed + content-hashed static files in production.
STORAGES = {
    'default': {
        'BACKEND': 'django.core.files.storage.FileSystemStorage',
    },
    'staticfiles': {
        'BACKEND': 'whitenoise.storage.CompressedManifestStaticFilesStorage',
    },
}
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
}

SIMPLE_JWT = {
    # Mobile sessions should behave like WhatsApp: sign in once and stay
    # signed in. The app silently refreshes the access token, and rotation
    # below extends the refresh token on every renewal, so active users are
    # never logged out.
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=24),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=60),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'USER_ID_FIELD': 'user_id',
    'USER_ID_CLAIM': 'user_id',
}

CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            "hosts": [env('REDIS_URL', default='redis://127.0.0.1:6379/0')],
        },
    },
}

CELERY_BROKER_URL = env('CELERY_BROKER_URL', default='redis://127.0.0.1:6379/1')

# ─── Celery Beat Schedule ────────────────────────────────────────────────────
try:
    from celery.schedules import crontab  # noqa: E402
    CELERY_BEAT_SCHEDULE = {
        'send-appointment-reminders': {
            'task': 'apps.appointments.tasks.send_appointment_reminders',
            'schedule': crontab(minute=0),
        },
        'send-medication-reminders': {
            'task': 'apps.consultations.tasks.send_medication_reminders',
            'schedule': crontab(minute='*/15'),  # every 15 minutes
        },
        'scrape-onmc-doctors-weekly': {
            'task': 'apps.admin_dashboard.tasks.scrape_and_store_onmc',
            'schedule': crontab(minute=0, hour=3, day_of_week=1),  # Mon 03:00
        },
        'sync-facilities-weekly': {
            'task': 'apps.admin_dashboard.tasks.sync_facilities',
            'schedule': crontab(minute=30, hour=3, day_of_week=1),  # Mon 03:30
        },
    }
except ImportError:
    pass
CELERY_TIMEZONE = 'Africa/Douala'

SPECTACULAR_SETTINGS = {
    'TITLE': 'Clinix API',
    'DESCRIPTION': 'Comprehensive mobile healthcare platform for Cameroon',
    'VERSION': '1.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
}

# ─── Email Configuration (for OTP sending) ─────────────────────────────────
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = env('EMAIL_HOST', default='smtp.gmail.com')
EMAIL_PORT = env.int('EMAIL_PORT', default=587)
EMAIL_USE_TLS = True
EMAIL_HOST_USER = env('EMAIL_HOST_USER', default='')
EMAIL_HOST_PASSWORD = env('EMAIL_HOST_PASSWORD', default='')
DEFAULT_FROM_EMAIL = env('DEFAULT_FROM_EMAIL', default='Clinix <noreply@clinix.app>')

# In development without email configured, use console backend
if not EMAIL_HOST_USER:
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# ─── CamPay Payment Gateway ────────────────────────────────────────────────────
CAMPAY_BASE_URL = env('CAMPAY_BASE_URL', default='https://demo.campay.net')
CAMPAY_USERNAME = env('CAMPAY_USERNAME', default='')
CAMPAY_PASSWORD = env('CAMPAY_PASSWORD', default='')
CAMPAY_WEBHOOK_URL = env('CAMPAY_WEBHOOK_URL', default='')

