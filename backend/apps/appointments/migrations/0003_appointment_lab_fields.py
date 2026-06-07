from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('appointments', '0002_appointment_address_appointment_service_name_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='appointment',
            name='lab_test_status',
            field=models.CharField(
                blank=True,
                choices=[
                    ('accepted', 'Accepted'),
                    ('ongoing', 'Sample Collected / Ongoing'),
                    ('results_ready', 'Results Ready'),
                ],
                max_length=20,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name='appointment',
            name='lab_results',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='appointment',
            name='lab_results_file_url',
            field=models.URLField(blank=True, null=True),
        ),
    ]
