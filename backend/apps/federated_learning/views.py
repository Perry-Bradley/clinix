from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import FederatedModelUpdate
from .serializers import FederatedModelUpdateSerializer

class SubmitModelUpdateView(generics.CreateAPIView):
    serializer_class = FederatedModelUpdateSerializer
    # Allow devices to submit without user auth if needed, but best practice is authenticated
    permission_classes = [permissions.IsAuthenticated]

class LatestModelMetadataView(APIView):
    permission_classes = [permissions.AllowAny]
    
    def get(self, request):
        return Response({
            'model_version': '1.0.0',
            'download_url': 'https://s3.amazonaws.com/clinix-media/models/symptom_classifier_v1.0.0.tflite',
            'checksum': 'abcd1234efgh5678'
        })
