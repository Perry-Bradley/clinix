from decimal import Decimal
from django.core.management.base import BaseCommand
from apps.accounts.models import User
from apps.providers.models import HealthcareProvider
from apps.locations.models import Location


PROVIDERS_DATA = [
    {
        "user": {
            "email": "dr.nkeng@clinix.cm",
            "phone_number": "+237670000001",
            "full_name": "Dr. Nkeng Emmanuel Fon",
            "user_type": "provider",
        },
        "provider": {
            "specialty": "generalist",
            "license_number": "CM-MED-2019-0451",
            "years_experience": 7,
            "bio": "General practitioner with expertise in tropical medicine and primary care. Fluent in English and French.",
            "consultation_fee": Decimal("15000.00"),
            "rating": Decimal("4.60"),
            "total_consultations": 312,
        },
        "location": {
            "location_type": "clinic",
            "facility_name": "Centre Medical de Bonanjo",
            "address": "Rue Joss, Bonanjo, Douala",
            "city": "Douala",
            "region": "Littoral",
            "latitude": Decimal("4.0435080"),
            "longitude": Decimal("9.6960680"),
        },
    },
    {
        "user": {
            "email": "nurse.mbah@clinix.cm",
            "phone_number": "+237670000002",
            "full_name": "Mbah Florence Ngum",
            "user_type": "provider",
        },
        "provider": {
            "specialty": "nurse",
            "license_number": "CM-NRS-2020-1127",
            "years_experience": 5,
            "bio": "Registered nurse specializing in maternal and child health. Experienced in community health outreach programs.",
            "consultation_fee": Decimal("10000.00"),
            "rating": Decimal("4.80"),
            "total_consultations": 189,
        },
        "location": {
            "location_type": "clinic",
            "facility_name": "Clinique La Cathedrale",
            "address": "Avenue Kennedy, Akwa, Douala",
            "city": "Douala",
            "region": "Littoral",
            "latitude": Decimal("4.0510920"),
            "longitude": Decimal("9.7042850"),
        },
    },
    {
        "user": {
            "email": "mw.tagne@clinix.cm",
            "phone_number": "+237670000003",
            "full_name": "Tagne Marie-Claire Djomou",
            "user_type": "provider",
        },
        "provider": {
            "specialty": "midwife",
            "license_number": "CM-MWF-2018-0783",
            "years_experience": 9,
            "bio": "Certified midwife with extensive experience in prenatal care, delivery assistance, and postnatal follow-up across urban and rural settings.",
            "consultation_fee": Decimal("12000.00"),
            "rating": Decimal("4.90"),
            "total_consultations": 540,
        },
        "location": {
            "location_type": "clinic",
            "facility_name": "Maternite de la Cite Verte",
            "address": "Quartier Cite Verte, Yaounde",
            "city": "Yaounde",
            "region": "Centre",
            "latitude": Decimal("3.8880320"),
            "longitude": Decimal("11.5020640"),
        },
    },
    {
        "user": {
            "email": "dr.atangana@clinix.cm",
            "phone_number": "+237670000004",
            "full_name": "Dr. Atangana Jean-Pierre Owona",
            "user_type": "provider",
        },
        "provider": {
            "specialty": "other",
            "other_specialty": "Dermatology",
            "license_number": "CM-MED-2015-0294",
            "years_experience": 12,
            "bio": "Dermatologist treating skin conditions common in tropical climates. Published researcher in tropical dermatology.",
            "consultation_fee": Decimal("25000.00"),
            "rating": Decimal("4.70"),
            "total_consultations": 410,
        },
        "location": {
            "location_type": "clinic",
            "facility_name": "Cabinet Medical Bastos",
            "address": "Rue 1839, Bastos, Yaounde",
            "city": "Yaounde",
            "region": "Centre",
            "latitude": Decimal("3.8841560"),
            "longitude": Decimal("11.5068230"),
        },
    },
    {
        "user": {
            "email": "dr.ngassa@clinix.cm",
            "phone_number": "+237670000005",
            "full_name": "Dr. Ngassa Blandine Kenfack",
            "user_type": "provider",
        },
        "provider": {
            "specialty": "generalist",
            "license_number": "CM-MED-2017-0612",
            "years_experience": 8,
            "bio": "Family medicine practitioner with a focus on preventive care and chronic disease management. Bilingual consultations available.",
            "consultation_fee": Decimal("18000.00"),
            "rating": Decimal("4.50"),
            "total_consultations": 275,
        },
        "location": {
            "location_type": "clinic",
            "facility_name": "Polyclinique de Deido",
            "address": "Boulevard de la Liberte, Deido, Douala",
            "city": "Douala",
            "region": "Littoral",
            "latitude": Decimal("4.0605230"),
            "longitude": Decimal("9.7092140"),
        },
    },
]


class Command(BaseCommand):
    help = "Seed the database with 5 test healthcare providers based in Cameroon"

    def handle(self, *args, **options):
        password = "Test1234!"
        created_count = 0
        existing_count = 0

        for data in PROVIDERS_DATA:
            # Try to find by email first, then by phone
            try:
                user = User.objects.get(email=data["user"]["email"])
                user_created = False
            except User.DoesNotExist:
                try:
                    user = User.objects.get(phone_number=data["user"]["phone_number"])
                    user_created = False
                except User.DoesNotExist:
                    user = User.objects.create(
                        email=data["user"]["email"],
                        phone_number=data["user"]["phone_number"],
                        full_name=data["user"]["full_name"],
                        user_type=data["user"]["user_type"],
                        is_active=True,
                        is_verified=True,
                    )
                    user.set_password(password)
                    user.save()
                    user_created = True

            provider_defaults = {
                "specialty": data["provider"]["specialty"],
                "license_number": data["provider"]["license_number"],
                "years_experience": data["provider"]["years_experience"],
                "bio": data["provider"]["bio"],
                "consultation_fee": data["provider"]["consultation_fee"],
                "verification_status": "approved",
                "is_available": True,
                "rating": data["provider"]["rating"],
                "total_consultations": data["provider"]["total_consultations"],
            }
            if "other_specialty" in data["provider"]:
                provider_defaults["other_specialty"] = data["provider"]["other_specialty"]

            provider, provider_created = HealthcareProvider.objects.get_or_create(
                provider_id=user,
                defaults=provider_defaults,
            )

            Location.objects.get_or_create(
                provider=provider,
                location_type=data["location"]["location_type"],
                defaults={
                    "facility_name": data["location"]["facility_name"],
                    "address": data["location"]["address"],
                    "city": data["location"]["city"],
                    "region": data["location"]["region"],
                    "latitude": data["location"]["latitude"],
                    "longitude": data["location"]["longitude"],
                },
            )

            if user_created and provider_created:
                created_count += 1
                self.stdout.write(self.style.SUCCESS(f"  Created: {user.full_name} ({provider.specialty})"))
            else:
                existing_count += 1
                self.stdout.write(self.style.WARNING(f"  Exists:  {user.full_name} ({provider.specialty})"))

        self.stdout.write("")
        self.stdout.write(self.style.SUCCESS(f"Done. Created {created_count} new provider(s), {existing_count} already existed."))
