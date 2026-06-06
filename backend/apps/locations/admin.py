from django.contrib import admin
from .models import Location

@admin.register(Location)
class LocationAdmin(admin.ModelAdmin):
    list_display = ('facility_name', 'location_type', 'city', 'region', 'phone_number', 'is_home_visit')
    list_filter = ('location_type', 'is_home_visit', 'city', 'region')
    search_fields = ('facility_name', 'address', 'city', 'region', 'phone_number')
    fieldsets = (
        ('Basic Information', {
            'fields': ('facility_name', 'location_type', 'provider')
        }),
        ('Address Details', {
            'fields': ('address', 'city', 'region')
        }),
        ('Contact Information', {
            'fields': ('phone_number',)
        }),
        ('Location Details', {
            'fields': ('latitude', 'longitude', 'is_home_visit')
        }),
    )
