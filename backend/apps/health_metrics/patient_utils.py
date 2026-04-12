from rest_framework.exceptions import PermissionDenied
from apps.patients.models import Patient


def get_or_create_patient_profile(user):
    """
    Health metrics and vitals are patient-only. Ensures a Patient row exists for this user.
    """
    if getattr(user, 'user_type', None) != 'patient':
        raise PermissionDenied('Only patients can access health metrics.')
    patient, _ = Patient.objects.get_or_create(
        patient_id=user,
        defaults={'gender': None, 'date_of_birth': None},
    )
    return patient
