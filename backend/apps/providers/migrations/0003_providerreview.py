from django.db import migrations, models
import django.db.models.deletion
import uuid


class Migration(migrations.Migration):

    dependencies = [
        ('appointments', '0001_initial'),
        ('patients', '0001_initial'),
        ('providers', '0002_remove_healthcareprovider_specialization_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='ProviderReview',
            fields=[
                ('review_id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('rating', models.PositiveSmallIntegerField()),
                ('comment', models.TextField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('appointment', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='provider_reviews', to='appointments.appointment')),
                ('patient', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='provider_reviews', to='patients.patient')),
                ('provider', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='reviews', to='providers.healthcareprovider')),
            ],
            options={
                'db_table': 'provider_reviews',
                'ordering': ['-created_at'],
            },
        ),
    ]
