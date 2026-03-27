from django.db import models
from apps.patients.models import Patient
from django.contrib.postgres.fields import ArrayField
import uuid

class AISymptomSession(models.Model):
    session_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='ai_sessions')
    symptoms_input = models.TextField()
    parsed_symptoms = ArrayField(models.TextField(), default=list, blank=True)
    triage_score = models.IntegerField(null=True, blank=True) # 1 (low) to 5 (emergency)
    ai_analysis = models.JSONField(blank=True, null=True)
    recommendation = models.TextField(blank=True, null=True)
    escalated_to_provider = models.BooleanField(default=False)
    model_version = models.CharField(max_length=50, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'ai_symptom_sessions'
