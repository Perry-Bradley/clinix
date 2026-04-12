from rest_framework import serializers
from .models import HeartRateReading, DailyActivity

class HeartRateReadingSerializer(serializers.ModelSerializer):
    class Meta:
        model = HeartRateReading
        fields = ['id', 'bpm', 'hrv_ms', 'respiratory_rate', 'measured_at']
        read_only_fields = ['id', 'measured_at']

class DailyActivitySerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyActivity
        fields = ['id', 'steps', 'distance_km', 'date']
        read_only_fields = ['id']
