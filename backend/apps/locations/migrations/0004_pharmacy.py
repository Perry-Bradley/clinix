from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('locations', '0003_location_phone_number'),
    ]

    operations = [
        migrations.CreateModel(
            name='Pharmacy',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('place_id', models.CharField(max_length=255, unique=True)),
                ('name', models.CharField(max_length=300)),
                ('address', models.TextField(blank=True, null=True)),
                ('city', models.CharField(blank=True, max_length=100, null=True)),
                ('latitude', models.DecimalField(blank=True, decimal_places=7, max_digits=10, null=True)),
                ('longitude', models.DecimalField(blank=True, decimal_places=7, max_digits=10, null=True)),
                ('phone_number', models.CharField(blank=True, max_length=30, null=True)),
                ('synced_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'db_table': 'pharmacies',
                'ordering': ['city', 'name'],
            },
        ),
    ]
