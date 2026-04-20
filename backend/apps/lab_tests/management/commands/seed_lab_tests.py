from django.core.management.base import BaseCommand
from apps.lab_tests.models import LabTest

TESTS = [
    {'name': 'Full Blood Count (FBC)', 'category': 'Blood', 'price': 5000, 'turnaround': '24h', 'sample_type': 'Blood (venous)', 'fasting_required': False, 'description': 'Measures red/white blood cells, hemoglobin, platelets. Screens for anemia, infection, and blood disorders.'},
    {'name': 'Malaria Rapid Test', 'category': 'Blood', 'price': 3000, 'turnaround': '30 min', 'sample_type': 'Blood (finger prick)', 'fasting_required': False, 'description': 'Detects malaria parasite antigens. Quick screening for Plasmodium falciparum.'},
    {'name': 'Blood Sugar (Fasting)', 'category': 'Blood', 'price': 3500, 'turnaround': '4h', 'sample_type': 'Blood (venous)', 'fasting_required': True, 'description': 'Measures glucose levels after 8-12 hours fasting. Screens for diabetes and prediabetes.'},
    {'name': 'Hemoglobin (Hb)', 'category': 'Blood', 'price': 2500, 'turnaround': '4h', 'sample_type': 'Blood (finger prick)', 'fasting_required': False, 'description': 'Checks hemoglobin level. Essential for detecting anemia, especially in pregnant women.'},
    {'name': 'Widal Test (Typhoid)', 'category': 'Blood', 'price': 4000, 'turnaround': '24h', 'sample_type': 'Blood (venous)', 'fasting_required': False, 'description': 'Detects antibodies against Salmonella typhi. Helps diagnose typhoid fever.'},
    {'name': 'HIV Rapid Test', 'category': 'STD', 'price': 3000, 'turnaround': '30 min', 'sample_type': 'Blood (finger prick)', 'fasting_required': False, 'description': 'Confidential screening for HIV-1 and HIV-2 antibodies.'},
    {'name': 'Hepatitis B Surface Antigen', 'category': 'STD', 'price': 5000, 'turnaround': '24h', 'sample_type': 'Blood (venous)', 'fasting_required': False, 'description': 'Screens for active Hepatitis B infection. Recommended for all adults.'},
    {'name': 'Hepatitis C Antibody', 'category': 'STD', 'price': 5000, 'turnaround': '24h', 'sample_type': 'Blood (venous)', 'fasting_required': False, 'description': 'Detects Hepatitis C antibodies. Important for early treatment.'},
    {'name': 'Urinalysis', 'category': 'Urine', 'price': 3000, 'turnaround': '4h', 'sample_type': 'Mid-stream urine', 'fasting_required': False, 'description': 'Analyzes urine for infections, kidney issues, diabetes markers, and more.'},
    {'name': 'Urine Culture', 'category': 'Urine', 'price': 7000, 'turnaround': '48h', 'sample_type': 'Mid-stream urine', 'fasting_required': False, 'description': 'Identifies specific bacteria causing urinary tract infections and tests antibiotic sensitivity.'},
    {'name': 'Pregnancy Test (urine)', 'category': 'Urine', 'price': 2000, 'turnaround': '15 min', 'sample_type': 'First morning urine', 'fasting_required': False, 'description': 'Detects hCG hormone to confirm pregnancy. Best with morning sample.'},
    {'name': 'Lipid Profile', 'category': 'Blood', 'price': 8000, 'turnaround': '24h', 'sample_type': 'Blood (venous)', 'fasting_required': True, 'description': 'Measures cholesterol (total, HDL, LDL) and triglycerides. Assesses cardiovascular risk.'},
    {'name': 'Liver Function Test (LFT)', 'category': 'Blood', 'price': 8000, 'turnaround': '24h', 'sample_type': 'Blood (venous)', 'fasting_required': False, 'description': 'Measures ALT, AST, bilirubin, albumin. Evaluates liver health.'},
    {'name': 'Kidney Function Test (RFT)', 'category': 'Blood', 'price': 7000, 'turnaround': '24h', 'sample_type': 'Blood (venous)', 'fasting_required': False, 'description': 'Measures creatinine, urea, electrolytes. Assesses kidney function.'},
    {'name': 'Chest X-Ray', 'category': 'Imaging', 'price': 15000, 'turnaround': '2h', 'sample_type': 'None (imaging)', 'fasting_required': False, 'description': 'X-ray of the chest to check lungs, heart, and rib cage. Requires visit to imaging center.'},
    {'name': 'Abdominal Ultrasound', 'category': 'Imaging', 'price': 20000, 'turnaround': '1h', 'sample_type': 'None (imaging)', 'fasting_required': True, 'description': 'Ultrasound scan of abdomen - liver, kidneys, spleen, bladder. Requires 6-hour fast.'},
    {'name': 'Syphilis (VDRL/RPR)', 'category': 'STD', 'price': 3500, 'turnaround': '24h', 'sample_type': 'Blood (venous)', 'fasting_required': False, 'description': 'Screening test for syphilis infection. Confirmatory tests available if positive.'},
    {'name': 'Blood Group & Rhesus', 'category': 'Blood', 'price': 3000, 'turnaround': '1h', 'sample_type': 'Blood (finger prick)', 'fasting_required': False, 'description': 'Determines ABO blood group and Rh factor. Essential before transfusion or surgery.'},
    {'name': 'ESR (Erythrocyte Sedimentation Rate)', 'category': 'Blood', 'price': 3000, 'turnaround': '2h', 'sample_type': 'Blood (venous)', 'fasting_required': False, 'description': 'Non-specific marker of inflammation. Elevated in infections, autoimmune conditions, and cancers.'},
    {'name': 'Stool Examination', 'category': 'Other', 'price': 3000, 'turnaround': '4h', 'sample_type': 'Fresh stool sample', 'fasting_required': False, 'description': 'Microscopic examination for parasites, ova, blood, and bacteria in stool.'},
]


class Command(BaseCommand):
    help = 'Seed the database with common lab tests and prices'

    def handle(self, *args, **options):
        created = 0
        for t in TESTS:
            _, was_created = LabTest.objects.get_or_create(name=t['name'], defaults=t)
            if was_created:
                created += 1
                self.stdout.write(self.style.SUCCESS(f"  Created: {t['name']}"))
            else:
                self.stdout.write(self.style.WARNING(f"  Exists:  {t['name']}"))
        self.stdout.write(self.style.SUCCESS(f"\nDone. Created {created} lab test(s)."))
