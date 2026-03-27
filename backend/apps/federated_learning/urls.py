from django.urls import path
from .views import SubmitModelUpdateView, LatestModelMetadataView

urlpatterns = [
    path('submit-update/', SubmitModelUpdateView.as_view(), name='submit_model_update'),
    path('model/latest/', LatestModelMetadataView.as_view(), name='latest_model_metadata'),
]
