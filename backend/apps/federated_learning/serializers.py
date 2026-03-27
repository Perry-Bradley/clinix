from rest_framework import serializers
from .models import FederatedModelUpdate

class FederatedModelUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = FederatedModelUpdate
        fields = '__all__'
        read_only_fields = ('update_id', 'submitted_at', 'aggregated')
