from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('locations', '0002_location_location_type_alter_location_provider'),
    ]

    operations = [
        migrations.AddField(
            model_name='location',
            name='phone_number',
            field=models.CharField(blank=True, help_text='Contact phone number for the facility', max_length=20, null=True),
        ),
    ]
