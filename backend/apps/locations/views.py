from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import get_user_model
from .models import Location
from .serializers import LocationUpdateSerializer
from apps.providers.models import HealthcareProvider
from apps.providers.serializers import ProviderPublicSerializer

User = get_user_model()

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
        # Return unique facility names from locations with phone numbers
        try:
            facilities = Location.objects.exclude(
                facility_name__isnull=True
            ).exclude(
                facility_name__exact=""
            ).values(
                'facility_name', 'address', 'city', 'phone_number', 'location_id'
            ).distinct('facility_name', 'address', 'city')
            
            data = [
                {
                    'facility_name': f['facility_name'],
                    'address': f['address'],
                    'city': f['city'],
                    'phone_number': f['phone_number'],
                    'location_id': str(f['location_id'])
                }
                for f in facilities
            ]
            return Response(data)
        except Exception as e:
            # If distinct fails, fall back to simple query
            facilities = Location.objects.exclude(
                facility_name__isnull=True
            ).exclude(
                facility_name__exact=""
            ).values(
                'facility_name', 'address', 'city', 'phone_number', 'location_id'
            )
            
            data = [
                {
                    'facility_name': f['facility_name'],
                    'address': f['address'],
                    'city': f['city'],
                    'phone_number': f['phone_number'],
                    'location_id': str(f['location_id'])
                }
                for f in facilities
            ]
            return Response(data)

class AdminFacilityUpdateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, location_id):
        # Check if user is superadmin
        if not request.user.is_superuser and request.user.user_type != 'superadmin':
            return Response({'error': 'Only admins can update facility phone numbers'}, status=status.HTTP_403_FORBIDDEN)

        try:
            location = Location.objects.get(location_id=location_id)
        except Location.DoesNotExist:
            return Response({'error': 'Location not found'}, status=status.HTTP_404_NOT_FOUND)

        phone_number = request.data.get('phone_number')
        if phone_number is not None:
            location.phone_number = phone_number
            location.save()
            return Response({
                'location_id': str(location.location_id),
                'facility_name': location.facility_name,
                'phone_number': location.phone_number
            })
        return Response({'error': 'phone_number is required'}, status=status.HTTP_400_BAD_REQUEST)
