from django.utils import timezone


class LastSeenMiddleware:
    """Update user.last_seen on every authenticated request (at most once per minute)."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        user = getattr(request, 'user', None)
        if user and user.is_authenticated:
            now = timezone.now()
            # Only write to DB if last_seen is stale (> 60s) to reduce writes
            if not user.last_seen or (now - user.last_seen).total_seconds() > 60:
                type(user).objects.filter(pk=user.pk).update(last_seen=now)

                # If this is a provider, sync is_available based on activity
                if user.user_type == 'provider':
                    try:
                        from apps.providers.models import HealthcareProvider
                        HealthcareProvider.objects.filter(
                            provider_id=user, is_available=False
                        ).update(is_available=True)
                    except Exception:
                        pass
        return response
