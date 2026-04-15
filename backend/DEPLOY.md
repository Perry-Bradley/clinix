# Deploying Clinix Backend to Railway

## 1. Prerequisites
- GitHub account with this repo pushed
- [Railway account](https://railway.app) (free tier works to test)

## 2. Create the project
1. Railway dashboard → **New Project** → **Deploy from GitHub repo** → select this repo
2. Set the **root directory** to `backend/` in the service settings
3. Railway auto-detects the Dockerfile and `railway.toml`

## 3. Add services
Add two extra services to the same project:
- **PostgreSQL** (New → Database → PostgreSQL)
- **Redis** (New → Database → Redis)

Railway will expose their connection strings as env vars automatically.

## 4. Set environment variables
In the backend service → **Variables** tab, add everything from your `.env`:

```
SECRET_KEY=<generate a new one for production>
DEBUG=False
DJANGO_SETTINGS_MODULE=clinix_project.settings.production
ALLOWED_HOSTS=*.up.railway.app,yourdomain.com
DATABASE_URL=${{ Postgres.DATABASE_URL }}
REDIS_URL=${{ Redis.REDIS_URL }}
CELERY_BROKER_URL=${{ Redis.REDIS_URL }}

# From your current .env:
AGORA_APP_ID=...
AGORA_APP_CERT=...
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=...
EMAIL_HOST_PASSWORD=...
DEFAULT_FROM_EMAIL=Clinix <noreply@clinix.cm>
GEMINI_API_KEY=...
CAMPAY_BASE_URL=https://demo.campay.net
CAMPAY_USERNAME=...
CAMPAY_PASSWORD=...
CAMPAY_WEBHOOK_URL=https://<your-app>.up.railway.app/api/v1/payments/campay/webhook/

# Firebase Admin — upload firebase_key.json as a file secret or paste JSON here:
FIREBASE_ADMIN_CREDENTIALS_JSON=<paste the entire firebase_key.json content>
```

## 5. Add Celery worker + beat services (for notifications)
Create two more services in the same project, each pointing to the same repo (`backend/` root):
- **celery-worker**: override start command to `celery -A clinix_project worker --loglevel=info`
- **celery-beat**: override start command to `celery -A clinix_project beat --loglevel=info`

Both need the same env vars as the web service.

## 6. Deploy
Push to GitHub → Railway auto-deploys. Check logs for `Listening on TCP address 0.0.0.0:$PORT`.

## 7. Update mobile app
In `clinix_mobile/lib/core/constants/api_constants.dart`:
```dart
static const String _host = 'https://your-app.up.railway.app';
```

Then `flutter clean && flutter pub get && flutter run`.

## 8. Seed test data (optional)
Open the Railway service → **Connect** → Shell:
```bash
python manage.py seed_providers
python manage.py createsuperuser
```

## 9. Health check
Visit `https://your-app.up.railway.app/api/v1/providers/nearby/` — should return JSON array.

---

## Alternative: Render

Same idea, but create 3 services from the same repo:
- Web Service (Dockerfile, root=`backend`)
- Background Worker (Command: `celery -A clinix_project worker --loglevel=info`)
- Cron Job (Command: `celery -A clinix_project beat --loglevel=info`)

Plus Postgres + Redis managed add-ons.

## Webhook URL update
After deploy, update `CAMPAY_WEBHOOK_URL` in both:
- Railway backend env vars
- CamPay dashboard webhook settings

The polling fallback in `PaymentStatusView` still works if webhooks fail.
