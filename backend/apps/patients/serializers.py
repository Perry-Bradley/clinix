from rest_framework import serializers
from .models import Patient
from apps.accounts.serializers import UserSerializer

class PatientProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(source='patient_id', read_only=True)
    
    class Meta:
        model = Patient
        fields = '__all__'
        read_only_fields = ('patient_id',)
