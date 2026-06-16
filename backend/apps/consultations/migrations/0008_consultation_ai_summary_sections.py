from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('consultations', '0007_consultation_ai_summary'),
    ]

    operations = [
        migrations.AddField(
            model_name='consultation',
            name='ai_summary_sections',
            field=models.JSONField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='consultation',
            name='ai_summary_submitted',
            field=models.BooleanField(default=False),
        ),
    ]
