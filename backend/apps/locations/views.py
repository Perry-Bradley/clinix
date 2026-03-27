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

    def put(self, request):
        try:
            provider = HealthcareProvider.objects.get(provider_id=request.user)
            location, _ = Location.objects.get_or_create(provider=provider)
            
            serializer = LocationUpdateSerializer(location, data=request.data, partial=True)
            if serializer.is_valid():
                serializer.save()
                return Response(serializer.data)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        except HealthcareProvider.DoesNotExist:
            return Response({'error': 'Only providers can update provider locations'}, status=status.HTTP_403_FORBIDDEN)

class FacilitiesListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        # Return unique facility names from locations
        facilities = Location.objects.exclude(facility_name__isnull=True).exclude(facility_name__exact="").values_list('facility_name', 'address', 'city').distinct()
        data = [{'facility_name': f[0], 'address': f[1], 'city': f[2]} for f in facilities]
        return Response(data)
