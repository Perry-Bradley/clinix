from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('admin_dashboard', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='VerificationDecisionLog',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('provider_user_id', models.UUIDField(db_index=True)),
                ('provider_name', models.CharField(blank=True, default='', max_length=300)),
                ('ai_decision', models.CharField(blank=True, default='', max_length=10)),
                ('ai_match_probability', models.FloatField(default=0.0)),
                ('ai_checks_passed', models.IntegerField(default=0)),
                ('ai_checks_failed', models.IntegerField(default=0)),
                ('ai_model', models.CharField(blank=True, default='', max_length=40)),
                ('admin_decision', models.CharField(max_length=10)),
                ('decided_by', models.CharField(blank=True, default='', max_length=200)),
                ('agreed', models.BooleanField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
            options={
                'db_table': 'verification_decision_logs',
                'ordering': ['-created_at'],
            },
        ),
    ]
