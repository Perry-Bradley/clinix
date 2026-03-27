import csv
from django.http import HttpResponse
from rest_framework import permissions

class IsSuperAdminUser(permissions.BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.user_type == 'superadmin')
