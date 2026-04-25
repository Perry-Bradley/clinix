from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('providers', '0005_specialty_provider_role'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='specialty',
            name='role',
        ),
        migrations.AlterModelOptions(
            name='specialty',
            options={'ordering': ['name']},
        ),
        migrations.AlterField(
            model_name='healthcareprovider',
            name='provider_role',
            field=models.CharField(
                choices=[
                    ('generalist', 'Generalist'),
                    ('specialist', 'Specialist'),
                    ('nurse', 'Nurse'),
                ],
                default='generalist', max_length=20,
            ),
        ),
    ]
