import uuid
from django.db import models


class LabTest(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    category = models.CharField(max_length=50, choices=[
        ('Blood', 'Blood'),
        ('Urine', 'Urine'),
        ('Imaging', 'Imaging'),
        ('STD', 'STD'),
        ('Other', 'Other'),
    ])
    price = models.IntegerField(help_text='Price in XAF')
    turnaround = models.CharField(max_length=50, help_text='e.g. 24h, 30 min')
    sample_type = models.CharField(max_length=100, help_text='e.g. Blood (venous), Mid-stream urine')
    fasting_required = models.BooleanField(default=False)
    description = models.TextField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['category', 'name']

    def __str__(self):
        return f"{self.name} ({self.category}) - {self.price} XAF"
