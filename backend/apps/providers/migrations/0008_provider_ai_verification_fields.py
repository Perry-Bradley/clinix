from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('providers', '0007_provider_role_lab_tech'),
    ]

    operations = [
        migrations.AddField(
            model_name='healthcareprovider',
            name='ai_match_probability',
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='healthcareprovider',
            name='ai_decision',
            field=models.CharField(blank=True, default='', max_length=10),
        ),
        migrations.AddField(
            model_name='healthcareprovider',
            name='ai_notes',
            field=models.TextField(blank=True, default=''),
        ),
        migrations.AddField(
            model_name='healthcareprovider',
            name='ai_checked_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='healthcareprovider',
            name='ai_auto_approved',
            field=models.BooleanField(default=False),
        ),
    ]
