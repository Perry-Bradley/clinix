from django.db import models


class OnmcDoctor(models.Model):
    """A doctor scraped from the ONMC (Ordre National des Médecins du Cameroun)
    public directory and stored here so we don't re-scrape on every request — a
    weekly Celery Beat job refreshes the table."""
    name = models.CharField(max_length=300)
    specialization = models.CharField(max_length=200, blank=True, default='')
    region = models.CharField(max_length=120, blank=True, default='')
    registration_number = models.CharField(max_length=60, blank=True, default='', db_index=True)
    source = models.CharField(max_length=300, blank=True, default='')
    scraped_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'onmc_doctors'
        ordering = ['name']

    def __str__(self):
        return f'{self.name} ({self.registration_number})'


class VerificationDecisionLog(models.Model):
    """Shadow-mode log: for every provider verification an admin finalises, we
    record what the AI recommended alongside the human's actual decision. This
    turns live usage into a real, labelled dataset -> we can compute a genuine
    accuracy / false-approve rate and later retrain the model on real outcomes.

    No FK to the provider (kept as a UUID + name snapshot) so the log survives
    even if the provider record is later deleted, and to avoid cross-app
    migration coupling."""
    provider_user_id = models.UUIDField(db_index=True)
    provider_name = models.CharField(max_length=300, blank=True, default='')

    # What the AI said.
    ai_decision = models.CharField(max_length=10, blank=True, default='')  # approve/review/reject
    ai_match_probability = models.FloatField(default=0.0)
    ai_checks_passed = models.IntegerField(default=0)
    ai_checks_failed = models.IntegerField(default=0)
    ai_model = models.CharField(max_length=40, blank=True, default='')

    # What the human said (the ground-truth label).
    admin_decision = models.CharField(max_length=10)  # approved/rejected
    decided_by = models.CharField(max_length=200, blank=True, default='')

    # Did the AI's confident call agree with the human? Null when the AI
    # abstained (decision == 'review'), so it's excluded from accuracy.
    agreed = models.BooleanField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'verification_decision_logs'
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.provider_name}: AI={self.ai_decision} / admin={self.admin_decision}'
