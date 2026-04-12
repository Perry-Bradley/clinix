from datetime import datetime, timedelta

from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from .models import HeartRateReading, DailyActivity
from .serializers import HeartRateReadingSerializer, DailyActivitySerializer
from .patient_utils import get_or_create_patient_profile


class HeartRateReadingListCreateView(generics.ListCreateAPIView):
    serializer_class = HeartRateReadingSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        patient = get_or_create_patient_profile(self.request.user)
        return HeartRateReading.objects.filter(patient=patient)

    def perform_create(self, serializer):
        patient = get_or_create_patient_profile(self.request.user)
        serializer.save(patient=patient)


class DailyActivitySyncView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        patient = get_or_create_patient_profile(request.user)
        date_str = request.data.get('date')
        if date_str:
            try:
                day = datetime.strptime(str(date_str)[:10], '%Y-%m-%d').date()
            except ValueError:
                day = timezone.now().date()
        else:
            day = timezone.now().date()

        activity, created = DailyActivity.objects.get_or_create(
            patient=patient,
            date=day,
            defaults={
                'steps': int(request.data.get('steps', 0)),
                'distance_km': float(request.data.get('distance_km', 0.0)),
            },
        )

        if not created:
            if 'steps' in request.data:
                activity.steps = int(request.data.get('steps', activity.steps))
            if 'distance_km' in request.data:
                activity.distance_km = float(request.data.get('distance_km', activity.distance_km))
            activity.save()

        serializer = DailyActivitySerializer(activity)
        return Response(serializer.data, status=status.HTTP_200_OK)


class HealthSummaryView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        patient = get_or_create_patient_profile(request.user)

        latest_hr = HeartRateReading.objects.filter(patient=patient).order_by('-measured_at').first()

        today = timezone.now().date()
        today_activity = DailyActivity.objects.filter(patient=patient, date=today).first()

        weekly_activity = []
        for i in range(6, -1, -1):
            d = today - timedelta(days=i)
            act = DailyActivity.objects.filter(patient=patient, date=d).first()
            weekly_activity.append({
                'date': d.isoformat(),
                'steps': act.steps if act else 0,
            })

        return Response({
            'latest_heart_rate': HeartRateReadingSerializer(latest_hr).data if latest_hr else None,
            'today_activity': DailyActivitySerializer(today_activity).data if today_activity else None,
            'weekly_activity': weekly_activity,
        })
