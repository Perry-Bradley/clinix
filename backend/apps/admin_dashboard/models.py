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
