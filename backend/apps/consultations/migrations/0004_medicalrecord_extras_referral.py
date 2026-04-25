import uuid
from django.contrib.postgres.fields import ArrayField
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('consultations', '0003_medicationreminder_medicationlog'),
        ('patients', '0001_initial'),
        ('providers', '0005_specialty_provider_role'),
    ]

    operations = [
        # MedicalRecord extras
        migrations.AddField(
            model_name='medicalrecord',
            name='authored_by',
            field=models.ForeignKey(
                blank=True, null=True, on_delete=models.deletion.SET_NULL,
                related_name='authored_records', to='providers.healthcareprovider',
            ),
        ),
        migrations.AddField(
            model_name='medicalrecord',
            name='title',
            field=models.CharField(blank=True, max_length=200, null=True),
        ),
        migrations.AddField(
            model_name='medicalrecord',
            name='chief_complaint',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='medicalrecord',
            name='examination_findings',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='medicalrecord',
            name='medications_summary',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='medicalrecord',
            name='shared_with',
            field=models.ManyToManyField(
                blank=True, related_name='shared_records', to='providers.healthcareprovider',
            ),
        ),
        migrations.AddField(
            model_name='medicalrecord',
            name='updated_at',
            field=models.DateTimeField(auto_now=True),
        ),
        migrations.AlterModelOptions(
            name='medicalrecord',
            options={'ordering': ['-created_at']},
        ),

        # Referral
        migrations.CreateModel(
            name='Referral',
            fields=[
                ('referral_id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('kind', models.CharField(choices=[('specialist', 'Specialist'), ('lab_test', 'Lab Test')], max_length=20)),
                ('target_hospital_name', models.CharField(blank=True, max_length=200, null=True)),
                ('target_hospital_address', models.CharField(blank=True, max_length=300, null=True)),
                ('target_hospital_place_id', models.CharField(blank=True, max_length=200, null=True)),
                ('test_name', models.CharField(blank=True, max_length=200, null=True)),
                ('reason', models.TextField()),
                ('status', models.CharField(choices=[('pending', 'Pending'), ('accepted', 'Accepted'), ('completed', 'Completed'), ('cancelled', 'Cancelled')], default='pending', max_length=20)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('patient', models.ForeignKey(on_delete=models.deletion.CASCADE, related_name='referrals', to='patients.patient')),
                ('referred_by', models.ForeignKey(null=True, on_delete=models.deletion.SET_NULL, related_name='outgoing_referrals', to='providers.healthcareprovider')),
                ('referred_to', models.ForeignKey(blank=True, null=True, on_delete=models.deletion.SET_NULL, related_name='incoming_referrals', to='providers.healthcareprovider')),
                ('medical_record', models.ForeignKey(blank=True, null=True, on_delete=models.deletion.SET_NULL, related_name='referrals', to='consultations.medicalrecord')),
            ],
            options={
                'db_table': 'referrals',
                'ordering': ['-created_at'],
            },
        ),
    ]
