import uuid
from django.db import models
from apps.accounts.models import User


class Conversation(models.Model):
    """A 1-to-1 direct chat between two users (typically patient + provider)."""
    conversation_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user_a = models.ForeignKey(User, on_delete=models.CASCADE, related_name='conversations_as_a')
    user_b = models.ForeignKey(User, on_delete=models.CASCADE, related_name='conversations_as_b')
    created_at = models.DateTimeField(auto_now_add=True)
    last_message_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'direct_conversations'
        unique_together = ('user_a', 'user_b')
        indexes = [
            models.Index(fields=['user_a', 'last_message_at']),
            models.Index(fields=['user_b', 'last_message_at']),
        ]

    @classmethod
    def get_or_create_between(cls, user1, user2):
        """Return (conversation, created) with deterministic user_a/user_b order."""
        a, b = sorted([user1, user2], key=lambda u: str(u.user_id))
        return cls.objects.get_or_create(user_a=a, user_b=b)

    def other_participant(self, user):
        return self.user_b if user == self.user_a else self.user_a


class DirectMessage(models.Model):
    TYPE_CHOICES = (
        ('text', 'Text'),
        ('image', 'Image'),
        ('file', 'File'),
    )

    message_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='direct_messages_sent')
    content = models.TextField(blank=True, default='')
    message_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='text')
    file_url = models.URLField(max_length=1024, blank=True, null=True)
    file_name = models.CharField(max_length=255, blank=True, null=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'direct_messages'
        ordering = ['created_at']
        indexes = [models.Index(fields=['conversation', 'created_at'])]
