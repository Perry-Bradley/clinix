from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path('django-admin/', admin.site.urls),
    path('api/v1/auth/', include('apps.accounts.urls')),
    path('api/v1/patients/', include('apps.patients.urls')),
    path('api/v1/providers/', include('apps.providers.urls')),
    path('api/v1/appointments/', include('apps.appointments.urls')),
    path('api/v1/consultations/', include('apps.consultations.urls')),
    path('api/v1/ai/', include('apps.ai_engine.urls')),
    path('api/v1/ai/federated/', include('apps.federated_learning.urls')),
    path('api/v1/payments/', include('apps.payments.urls')),
    path('api/v1/system/settings/fee/', include([
        path('', include('apps.payments.urls_settings')),
    ])),
    path('api/v1/notifications/', include('apps.notifications.urls')),
    path('api/v1/dchat/', include('apps.direct_chat.urls')),
    path('api/v1/locations/', include('apps.locations.urls')),
    path('api/v1/admin/', include('apps.admin_dashboard.urls')),
    path('api/v1/health/', include('apps.health_metrics.urls')),
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
]
