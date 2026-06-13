from django.db import migrations, models


class Migration(migrations.Migration):
    """Adds the lab_tech choice to provider_role (choices-only change; no
    actual column alteration, but keeps the migration state in sync so the
    deploy-time 'unmigrated changes' warning goes away)."""

    dependencies = [
        ('providers', '0006_drop_specialty_role'),
    ]

    operations = [
        migrations.AlterField(
            model_name='healthcareprovider',
            name='provider_role',
            field=models.CharField(
                choices=[
                    ('generalist', 'Generalist'),
                    ('specialist', 'Specialist'),
                    ('nurse', 'Nurse'),
                    ('lab_tech', 'Lab Technician'),
                ],
                default='generalist',
                max_length=20,
            ),
        ),
    ]
