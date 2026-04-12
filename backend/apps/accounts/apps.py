from django.apps import AppConfig

class AccountsConfig(AppConfig):
    name = 'apps.accounts'

    def ready(self):
        from .firebase_config import initialize_firebase
        initialize_firebase()
