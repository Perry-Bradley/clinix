from django.urls import path
from .views import ProviderMapView, ProviderLocationUpdateView, FacilitiesListView

urlpatterns = [
    path('providers/map/', ProviderMapView.as_view(), name='providers_map'),
    path('provider/', ProviderLocationUpdateView.as_view(), name='location_provider'),
    path('facilities/', FacilitiesListView.as_view(), name='facilities_list'),
]
