"""JWT-based authentication middleware for Channels WebSockets.

Reads ?token=<access_token> from the WebSocket URL query string,
verifies it with SimpleJWT, and sets scope['user'].
"""
from urllib.parse import parse_qs
from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from django.contrib.auth.models import AnonymousUser


@database_sync_to_async
def _get_user_from_token(token):
    try:
        from rest_framework_simplejwt.tokens import AccessToken
        from django.contrib.auth import get_user_model
        User = get_user_model()
        validated = AccessToken(token)
        user_id = validated['user_id']
        return User.objects.get(pk=user_id)
    except Exception:
        return AnonymousUser()


class JWTAuthMiddleware(BaseMiddleware):
    async def __call__(self, scope, receive, send):
        query_string = scope.get('query_string', b'').decode()
        params = parse_qs(query_string)
        token = (params.get('token') or [None])[0]

        if token:
            user = await _get_user_from_token(token)
        else:
            user = AnonymousUser()

        scope['user'] = user
        return await super().__call__(scope, receive, send)


def JWTAuthMiddlewareStack(inner):
    """Wrap the inner ASGI app with JWT auth."""
    return JWTAuthMiddleware(inner)
