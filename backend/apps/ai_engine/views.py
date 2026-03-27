from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from .models import AISymptomSession
from apps.patients.models import Patient
from .serializers import AISymptomSessionSerializer, SymptomCheckRequestSerializer

from .symptom_processor import extract_symptoms, calculate_triage_score
from .diagnostic_engine import match_conditions

def process_symptoms(text, duration, severity, age, gender):
    symptoms, codes = extract_symptoms(text)
    triage_score = calculate_triage_score(symptoms, duration, severity)
    diagnosis = match_conditions(symptoms)
    
    escalate = triage_score >= 4
    if triage_score == 5:
        recommendation = "EMERGENCY: Seek immediate medical attention or go to the nearest hospital."
    else:
        recommendation = diagnosis['recommendation_text']
        
    analysis = {
        'extracted_symptoms': symptoms,
        'icd10_codes': codes,
        'top_condition': diagnosis['suggestions'][0],
        'confidence': diagnosis['confidence_score']
    }
    
    return {
        'triage_score': triage_score,
        'analysis': analysis,
        'recommendation': recommendation,
        'should_escalate': escalate,
        'suggested_specialization': diagnosis['recommended_specialization']
    }

class SymptomCheckView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = SymptomCheckRequestSerializer(data=request.data)
        if serializer.is_valid():
            try:
                patient = Patient.objects.get(patient_id=request.user)
            except Patient.DoesNotExist:
                return Response({'error': 'Only patients can use the symptom checker'}, status=status.HTTP_403_FORBIDDEN)
                
            data = serializer.validated_data
            result = process_symptoms(
                data['symptoms'], data['duration'], data['severity'],
                data['patient_age'], data['gender']
            )
            
            session = AISymptomSession.objects.create(
                patient=patient,
                symptoms_input=data['symptoms'],
                triage_score=result['triage_score'],
                ai_analysis=result['analysis'],
                recommendation=result['recommendation'],
                escalated_to_provider=result['should_escalate'],
                model_version='1.0.0'
            )
            
            return Response({
                'session_id': session.session_id,
                'triage_score': result['triage_score'],
                'analysis': result['analysis'],
                'recommendation': result['recommendation'],
                'should_escalate': result['should_escalate'],
                'suggested_specialization': result['suggested_specialization']
            })
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class AISessionDetailView(generics.RetrieveAPIView):
    serializer_class = AISymptomSessionSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        # Only allow patients to see their own sessions
        return AISymptomSession.objects.filter(patient__patient_id=self.request.user)
