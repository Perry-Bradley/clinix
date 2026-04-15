from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
import uuid

class UserManager(BaseUserManager):
    def create_user(self, email=None, phone_number=None, password=None, **extra_fields):
        if not email and not phone_number:
            raise ValueError('Either Email or Phone Number must be set')
        
        if email:
            email = self.normalize_email(email)
            
        user = self.model(email=email, phone_number=phone_number, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('user_type', 'superadmin')
        return self.create_user(email=email, password=password, **extra_fields)

class User(AbstractBaseUser, PermissionsMixin):
    USER_TYPE_CHOICES = (
        ('unassigned', 'Unassigned'),
        ('patient', 'Patient'),
        ('provider', 'Provider'),
        ('superadmin', 'Superadmin'),
    )

    LANGUAGE_CHOICES = (
        ('en', 'English'),
        ('fr', 'French'),
    )

    user_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone_number = models.CharField(max_length=20, unique=True, null=True, blank=True)
    email = models.EmailField(max_length=255, unique=True, null=True, blank=True)
    user_type = models.CharField(max_length=20, choices=USER_TYPE_CHOICES, default='unassigned')
    full_name = models.CharField(max_length=255, blank=True, null=True)
    profile_photo = models.URLField(max_length=500, blank=True, null=True)
    language_pref = models.CharField(max_length=2, choices=LANGUAGE_CHOICES, default='en')
    fcm_token = models.CharField(max_length=512, blank=True, null=True)
    
    is_active = models.BooleanField(default=True)
    is_verified = models.BooleanField(default=False)
    is_staff = models.BooleanField(default=False) # For django admin access
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    last_seen = models.DateTimeField(null=True, blank=True)

    objects = UserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []

    class Meta:
        db_table = 'users'

    def __str__(self):
        return f"{self.email or self.phone_number} - {self.user_type}"
