from .base import *
import environ

env = environ.Env()

DEBUG = env.bool('DEBUG', default=False)
ALLOWED_HOSTS = env.list('ALLOWED_HOSTS', default=['*'])

CORS_ALLOWED_ORIGINS = env.list('CORS_ALLOWED_ORIGINS', default=[
    'https://admin.clinix.cm',
    'https://merry-possibility-production-9743.up.railway.app'
])

# Allow all origins for debugging (remove in production for security)
CORS_ALLOW_ALL_ORIGINS = True

SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
