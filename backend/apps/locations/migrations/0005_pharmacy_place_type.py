from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('locations', '0004_pharmacy'),
    ]

    operations = [
        migrations.AddField(
            model_name='pharmacy',
            name='place_type',
            field=models.CharField(
                choices=[('pharmacy', 'Pharmacy'), ('hospital', 'Hospital')],
                default='pharmacy',
                max_length=20,
            ),
        ),
    ]
