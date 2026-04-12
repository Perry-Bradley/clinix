from django.db import models
from apps.patients.models import Patient

class HeartRateReading(models.Model):
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='heart_rate_readings')
    bpm = models.IntegerField()
    hrv_ms = models.FloatField(null=True, blank=True)
    respiratory_rate = models.IntegerField(null=True, blank=True)
    measured_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-measured_at']

    def __str__(self):
        name = getattr(self.patient.patient_id, 'full_name', None) or str(self.patient.patient_id)
        return f"{name} - {self.bpm} BPM at {self.measured_at}"

class DailyActivity(models.Model):
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='daily_activities')
    steps = models.IntegerField(default=0)
    distance_km = models.FloatField(default=0.0)
    date = models.DateField()

    class Meta:
        unique_together = ('patient', 'date')
        ordering = ['-date']

    def __str__(self):
        name = getattr(self.patient.patient_id, 'full_name', None) or str(self.patient.patient_id)
        return f"{name} - {self.steps} steps on {self.date}"
