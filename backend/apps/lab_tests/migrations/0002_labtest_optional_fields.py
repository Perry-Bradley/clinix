from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('lab_tests', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='labtest',
            name='turnaround',
            field=models.CharField(blank=True, default='', help_text='e.g. 24h, 30 min', max_length=50),
        ),
        migrations.AlterField(
            model_name='labtest',
            name='sample_type',
            field=models.CharField(blank=True, default='', help_text='e.g. Blood (venous), Mid-stream urine', max_length=100),
        ),
        migrations.AlterField(
            model_name='labtest',
            name='description',
            field=models.TextField(blank=True, default=''),
        ),
    ]
