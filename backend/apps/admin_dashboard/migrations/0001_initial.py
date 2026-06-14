from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name='OnmcDoctor',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=300)),
                ('specialization', models.CharField(blank=True, default='', max_length=200)),
                ('region', models.CharField(blank=True, default='', max_length=120)),
                ('registration_number', models.CharField(blank=True, db_index=True, default='', max_length=60)),
                ('source', models.CharField(blank=True, default='', max_length=300)),
                ('scraped_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'db_table': 'onmc_doctors',
                'ordering': ['name'],
            },
        ),
    ]
