from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('payments', '0003_providerwallet_withdrawalrequest_wallettransaction'),
    ]

    operations = [
        migrations.AddField(
            model_name='payment',
            name='external_transaction_id',
            field=models.CharField(blank=True, max_length=255, null=True),
        ),
        migrations.AddField(
            model_name='payment',
            name='payer_phone',
            field=models.CharField(blank=True, max_length=20, null=True),
        ),
    ]
