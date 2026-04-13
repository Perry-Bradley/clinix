import random
import uuid
from datetime import date, datetime, time, timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.accounts.models import User
from apps.patients.models import Patient
from apps.providers.models import HealthcareProvider
from apps.locations.models import Location
from apps.appointments.models import Appointment
from apps.consultations.models import Consultation, ChatMessage
from apps.payments.models import Payment, PlatformSetting


class Command(BaseCommand):
    help = 'Seeds demo patients, approved providers with locations, appointments, consultations, and sample chat.'

    def handle(self, *args, **kwargs):
        self.stdout.write('Seeding Clinix demo data...')

        setting, _ = PlatformSetting.objects.get_or_create(id=1)
        setting.consultation_fee = 15000
        setting.service_charge = 500
        setting.save()

        # ─── Admin (dashboard login) ─────────────────────────────────────
        admin_email = 'admin@clinix.cm'
        if not User.objects.filter(email=admin_email).exists():
            User.objects.create_superuser(
                email=admin_email,
                password='admin12345',
                phone_number='+237900000001',
                full_name='Clinix Admin',
            )
            self.stdout.write(self.style.SUCCESS(f'Admin created: {admin_email} / admin12345'))
        else:
            self.stdout.write(f'Admin already exists: {admin_email}')

        # ─── Demo patient (app testing: AI, health, bookings) ────────────
        demo_email = 'patient@demo.clinix.cm'
        demo_phone = '+237650000001'
        patient_user, pu_created = User.objects.get_or_create(
            email=demo_email,
            defaults={
                'phone_number': demo_phone,
                'full_name': 'Demo Patient',
                'user_type': 'patient',
                'is_verified': True,
            },
        )
        if pu_created:
            patient_user.set_password('demo12345')
            patient_user.save()
            self.stdout.write(self.style.SUCCESS(f'Demo patient created: {demo_email} / demo12345'))
        else:
            self.stdout.write(f'Demo patient exists: {demo_email}')

        demo_patient, _ = Patient.objects.get_or_create(
            patient_id=patient_user,
            defaults={
                'date_of_birth': date(1992, 6, 15),
                'gender': 'male',
            },
        )

        # ─── Demo providers (all approved, with clinic locations) ───────
        providers_seed = [
            {
                'full_name': 'Dr. Marie Nkomo',
                'email': 'marie@demo.clinix.cm',
                'phone': '+237670010001',
                'specialty': 'generalist',
                'other_specialty': 'Internal Medicine & Cardiology',
                'bio': 'General internist with focus on hypertension and diabetes. 12+ years in Yaoundé.',
                'fee': 15000,
                'lat': '3.8480',
                'lng': '11.5021',
                'facility': 'Clinix Medical Centre — Bastos',
                'address': 'Rue Joseph Mballa Eloumden',
                'city': 'Yaoundé',
            },
            {
                'full_name': 'Dr. Samuel Fotsing',
                'email': 'samuel@demo.clinix.cm',
                'phone': '+237670010002',
                'specialty': 'generalist',
                'other_specialty': 'Pediatrics',
                'bio': 'Pediatric consultations, vaccinations, and growth monitoring.',
                'fee': 12000,
                'lat': '3.8667',
                'lng': '11.5167',
                'facility': 'Clinix Kids Clinic — Mokolo',
                'address': 'Avenue Kennedy',
                'city': 'Yaoundé',
            },
            {
                'full_name': 'Dr. Grace Abena',
                'email': 'grace@demo.clinix.cm',
                'phone': '+237670010003',
                'specialty': 'midwife',
                'other_specialty': None,
                'bio': 'Prenatal care, delivery planning, and postnatal follow-up.',
                'fee': 10000,
                'lat': '3.8340',
                'lng': '11.5210',
                'facility': 'Clinix Women’s Health — Essos',
                'address': 'Carrefour Essos',
                'city': 'Yaoundé',
            },
            {
                'full_name': 'Dr. Paul Mbarga',
                'email': 'paul@demo.clinix.cm',
                'phone': '+237670010004',
                'specialty': 'nurse',
                'other_specialty': 'Community health & wound care',
                'bio': 'Home visits and clinic-based nursing care.',
                'fee': 8000,
                'lat': '3.8720',
                'lng': '11.4880',
                'facility': 'Clinix Nursing Station — Nlongkak',
                'address': 'Boulevard de la Liberté',
                'city': 'Yaoundé',
            },
            {
                'full_name': 'Dr. Linda Tchameni',
                'email': 'linda@demo.clinix.cm',
                'phone': '+237670010005',
                'specialty': 'generalist',
                'other_specialty': 'Dermatology',
                'bio': 'Skin consultations, chronic rash follow-up, and outpatient dermatology care.',
                'fee': 14000,
                'lat': '3.8791',
                'lng': '11.5102',
                'facility': 'Clinix Skin Care — Melen',
                'address': 'Avenue Melen',
                'city': 'Yaoundé',
            },
        ]

        providers = []
        for i, row in enumerate(providers_seed):
            u, created = User.objects.get_or_create(
                email=row['email'],
                defaults={
                    'phone_number': row['phone'],
                    'full_name': row['full_name'],
                    'user_type': 'provider',
                    'is_verified': True,
                },
            )
            if created:
                u.set_password('provider123')
                u.save()
                self.stdout.write(self.style.SUCCESS(f'Provider user: {row["email"]} / provider123'))

            lic = f'CM-DEMO-{1001 + i}'
            hp, hp_created = HealthcareProvider.objects.get_or_create(
                provider_id=u,
                defaults={
                    'specialty': row['specialty'],
                    'other_specialty': row.get('other_specialty') or '',
                    'license_number': lic,
                    'years_experience': 8 + i,
                    'bio': row['bio'],
                    'consultation_fee': row['fee'],
                    'verification_status': 'approved',
                    'is_available': True,
                    'rating': round(4.2 + random.random() * 0.7, 2),
                    'total_consultations': 20 + i * 5,
                },
            )
            if not hp_created:
                hp.verification_status = 'approved'
                hp.is_available = True
                hp.consultation_fee = row['fee']
                hp.save(update_fields=['verification_status', 'is_available', 'consultation_fee'])

            Location.objects.get_or_create(
                provider=hp,
                facility_name=row['facility'],
                defaults={
                    'location_type': 'clinic',
                    'address': row['address'],
                    'city': row['city'],
                    'region': 'Centre',
                    'latitude': row['lat'],
                    'longitude': row['lng'],
                    'is_home_visit': False,
                },
            )
            providers.append(hp)

        # ─── Bookable appointments + consultations + chat (for demo patient) ─
        marie = providers[0]
        samuel = providers[1]

        def ensure_consultation_with_chat(prov, days_ahead: int, status: str):
            day = (timezone.now() + timedelta(days=days_ahead)).date()
            apt = Appointment.objects.filter(
                patient=demo_patient,
                provider=prov,
                scheduled_at__date=day,
            ).first()
            if not apt:
                apt = Appointment.objects.create(
                    patient=demo_patient,
                    provider=prov,
                    scheduled_at=timezone.make_aware(datetime.combine(day, time(10, 30))),
                    appointment_type='virtual',
                    status=status,
                    duration_minutes=30,
                )
            elif apt.status != status:
                apt.status = status
                apt.save(update_fields=['status'])

            con, c_created = Consultation.objects.get_or_create(
                appointment=apt,
                defaults={
                    'started_at': timezone.now() - timedelta(hours=1) if status == 'confirmed' else None,
                    'webrtc_session_id': str(uuid.uuid4()),
                    'consultation_type': 'hybrid',
                },
            )
            if c_created or not con.messages.exists():
                ChatMessage.objects.create(
                    consultation=con,
                    sender=patient_user,
                    message_type='text',
                    content='Hello doctor, I wanted to follow up on my last visit.',
                )
                ChatMessage.objects.create(
                    consultation=con,
                    sender=prov.provider_id,
                    message_type='text',
                    content='Good to hear from you. How have your symptoms been since we last spoke?',
                )
            return con

        c1 = ensure_consultation_with_chat(marie, days_ahead=2, status='confirmed')
        c2 = ensure_consultation_with_chat(samuel, days_ahead=5, status='confirmed')

        self.stdout.write(self.style.SUCCESS(
            f'Consultation IDs for chat/video tests: {c1.consultation_id}, {c2.consultation_id}'
        ))

        # ─── Sample completed appointment + payment (revenue demo) ─────────
        if providers:
            prov = providers[0]
            past_day = (timezone.now() - timedelta(days=3)).date()
            apt_done = Appointment.objects.filter(
                patient=demo_patient,
                provider=prov,
                status='completed',
            ).first()
            if not apt_done:
                apt_done = Appointment.objects.create(
                    patient=demo_patient,
                    provider=prov,
                    scheduled_at=timezone.make_aware(datetime.combine(past_day, time(14, 0))),
                    appointment_type='virtual',
                    status='completed',
                    duration_minutes=30,
                )
            Consultation.objects.get_or_create(
                appointment=apt_done,
                defaults={
                    'started_at': timezone.now() - timedelta(days=3),
                    'ended_at': timezone.now() - timedelta(days=3) + timedelta(minutes=25),
                    'provider_notes': 'Stable on current medication. Review in 4 weeks.',
                    'consultation_type': 'provider',
                },
            )
            if not Payment.objects.filter(appointment=apt_done).exists():
                Payment.objects.create(
                    appointment=apt_done,
                    patient=demo_patient,
                    provider=prov,
                    amount=15000,
                    payment_method='mtn_momo',
                    status='success',
                    transaction_ref=f'TXN-DEMO-{uuid.uuid4().hex[:8].upper()}',
                    platform_fee=1500,
                    provider_payout=13500,
                    completed_at=timezone.now() - timedelta(days=3),
                )

        self.stdout.write(self.style.SUCCESS('Done. Use demo patient for AI + health; providers for inbox / calls.'))
