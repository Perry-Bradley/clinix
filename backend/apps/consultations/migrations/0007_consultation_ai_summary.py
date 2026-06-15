from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('consultations', '0006_consultation_audio_gs_uri_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='consultation',
            name='ai_summary',
            field=models.TextField(blank=True, default=''),
        ),
    ]
