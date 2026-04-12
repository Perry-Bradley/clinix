from rest_framework import serializers
from apps.patients.models import Patient
from apps.accounts.models import User

class AdminPatientSerializer(serializers.ModelSerializer):
    patient_id = serializers.UUIDField(source='patient_id.user_id', read_only=True)
    first_name = serializers.CharField(source='patient_id.first_name', required=False, allow_blank=True)
    last_name = serializers.CharField(source='patient_id.last_name', required=False, allow_blank=True)
    email = serializers.EmailField(source='patient_id.email', required=False, allow_blank=True)
    phone_number = serializers.CharField(source='patient_id.phone_number', required=False)
    date_of_birth = serializers.DateField(required=False, allow_null=True)
    
    class Meta:
        model = Patient
        fields = ['patient_id', 'first_name', 'last_name', 'email', 'phone_number', 'date_of_birth', 'gender', 'blood_type']
        
    def create(self, validated_data):
        user_data = validated_data.pop('patient_id', {})
        phone = user_data.get('phone_number')
        
        user = User.objects.create_user(
            phone_number=phone,
            password='Password123!', # Default password for admin created
            user_type='patient',
            first_name=user_data.get('first_name', ''),
            last_name=user_data.get('last_name', ''),
            email=user_data.get('email', f"{phone}@clinix.demo")
        )
        patient = Patient.objects.create(patient_id=user, **validated_data)
        return patient

    def update(self, instance, validated_data):
        user_data = validated_data.pop('patient_id', {})
        user = instance.patient_id
        
        if 'first_name' in user_data:
            user.first_name = user_data['first_name']
        if 'last_name' in user_data:
            user.last_name = user_data['last_name']
        if 'email' in user_data:
            user.email = user_data['email']
        if 'phone_number' in user_data:
            user.phone_number = user_data['phone_number']
        user.save()
        
        instance.date_of_birth = validated_data.get('date_of_birth', instance.date_of_birth)
        instance.gender = validated_data.get('gender', instance.gender)
        instance.blood_type = validated_data.get('blood_type', instance.blood_type)
        instance.save()
        
        return instance
