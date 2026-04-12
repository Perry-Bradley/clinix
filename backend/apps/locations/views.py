from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Location
from .serializers import LocationUpdateSerializer
from apps.providers.models import HealthcareProvider
from apps.providers.serializers import ProviderPublicSerializer

class ProviderMapView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        bounds_str = request.query_params.get('bounds')
        queryset = HealthcareProvider.objects.filter(verification_status='approved')
        
        if bounds_str:
            try:
                lat1, lng1, lat2, lng2 = map(float, bounds_str.split(','))
                min_lat, max_lat = min(lat1, lat2), max(lat1, lat2)
                min_lng, max_lng = min(lng1, lng2), max(lng1, lng2)
                
                locations = Location.objects.filter(
                    latitude__range=(min_lat, max_lat),
                    longitude__range=(min_lng, max_lng)
                )
                queryset = queryset.filter(location__in=locations)
            except ValueError:
                pass
                
        serializer = ProviderPublicSerializer(queryset, many=True)
        return Response(serializer.data)

class ProviderLocationUpdateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        return self._upsert(request)

    def put(self, request):
        return self._upsert(request)

    def _upsert(self, request):
        try:
            provider = HealthcareProvider.objects.get(provider_id=request.user)
        except HealthcareProvider.DoesNotExist:
            return Response({'error': 'Only providers can update provider locations'}, status=status.HTTP_403_FORBIDDEN)

        location_type = request.data.get('location_type') or 'residence'
        instance = Location.objects.filter(provider=provider, location_type=location_type).first()

        serializer = LocationUpdateSerializer(instance, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        obj = serializer.save(provider=provider)
        return Response(LocationUpdateSerializer(obj).data)

class FacilitiesListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        # Return unique facility names from locations
        facilities = Location.objects.exclude(facility_name__isnull=True).exclude(facility_name__exact="").values_list('facility_name', 'address', 'city').distinct()
        data = [{'facility_name': f[0], 'address': f[1], 'city': f[2]} for f in facilities]
        return Response(data)
