import uuid
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('providers', '0004_alter_providercredential_document_type_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='Specialty',
            fields=[
                ('specialty_id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('name', models.CharField(max_length=120, unique=True)),
                ('role', models.CharField(choices=[('specialist', 'Specialist'), ('nurse', 'Nurse')], default='specialist', max_length=20)),
                ('description', models.TextField(blank=True, null=True)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
            options={
                'db_table': 'specialties',
                'ordering': ['role', 'name'],
            },
        ),
        migrations.AddField(
            model_name='healthcareprovider',
            name='provider_role',
            field=models.CharField(
                choices=[('generalist', 'Generalist'), ('specialist', 'Specialist'), ('nurse', 'Nurse')],
                default='generalist', max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='healthcareprovider',
            name='specialty_obj',
            field=models.ForeignKey(
                blank=True, null=True, on_delete=models.deletion.SET_NULL,
                related_name='providers', to='providers.specialty',
            ),
        ),
    ]
