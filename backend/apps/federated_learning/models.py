from django.db import models
import uuid

class FederatedModelUpdate(models.Model):
    update_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device_id = models.CharField(max_length=255)
    model_version = models.CharField(max_length=50)
    gradient_hash = models.CharField(max_length=255)
    update_size_kb = models.IntegerField()
    submitted_at = models.DateTimeField(auto_now_add=True)
    aggregated = models.BooleanField(default=False)

    class Meta:
        db_table = 'federated_model_updates'
