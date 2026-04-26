FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system deps
RUN apt-get update && apt-get install -y \
    libpq-dev gcc curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Bake static files into the image so WhiteNoise can serve the Django admin
# (and any other static asset) in production. Real SECRET_KEY / DB only
# exist at runtime, so we feed safe placeholders just for collectstatic.
ENV DJANGO_SETTINGS_MODULE=clinix_project.settings.production
RUN SECRET_KEY=build-only-placeholder \
    DEBUG=False \
    DATABASE_URL=sqlite:///tmp/build.db \
    python manage.py collectstatic --noinput --clear

EXPOSE 8000
