from django.db import models
from apps.patients.models import Patient
from django.contrib.postgres.fields import ArrayField
import uuid

class AISymptomSession(models.Model):
    session_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='ai_sessions')
    symptoms_input = models.TextField(blank=True, null=True) # First user message
    is_active = models.BooleanField(default=True) # Is the chat still ongoing?
    triage_score = models.IntegerField(null=True, blank=True)
    ai_analysis = models.JSONField(blank=True, null=True)
    recommendation = models.TextField(blank=True, null=True)
    suggested_specialization = models.CharField(max_length=100, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'ai_symptom_sessions'

class AIChatMessage(models.Model):
    session = models.ForeignKey(AISymptomSession, on_delete=models.CASCADE, related_name='messages')
    sender = models.CharField(max_length=10, choices=[('user', 'User'), ('ai', 'AI')])
    message = models.TextField()
    image = models.TextField(blank=True, null=True, help_text="Base64 encoded image or image URL")
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['timestamp']
        db_table = 'ai_chat_messages'
