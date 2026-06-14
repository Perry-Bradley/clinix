import logging

try:
    from celery import shared_task
except ImportError:  # Celery not installed locally — make it a no-op decorator
    def shared_task(fn):
        return fn

logger = logging.getLogger(__name__)


@shared_task
def scrape_and_store_onmc():
    """Scrape the ONMC directory and replace the stored snapshot in the DB.

    Runs weekly via Celery Beat (and on-demand from the admin). We store the
    result so the admin dashboard reads instantly from the DB instead of
    re-scraping 64 pages on every visit."""
    from django.db import transaction
    from .views import _scrape_onmc_doctors, ONMC_DIRECTORY
    from .models import OnmcDoctor

    entries, err, pages = _scrape_onmc_doctors()
    if not entries:
        logger.warning('ONMC scrape stored nothing (pages=%s, err=%s)', pages, err)
        return {'stored': 0, 'pages': pages, 'error': err}

    objs = [
        OnmcDoctor(
            name=e.get('name', ''),
            specialization=e.get('specialization', '') or '',
            region=e.get('region', '') or '',
            registration_number=e.get('registration_number', '') or '',
            source=ONMC_DIRECTORY,
        )
        for e in entries if e.get('name')
    ]
    # Replace the snapshot atomically so readers never see a half-empty table.
    with transaction.atomic():
        OnmcDoctor.objects.all().delete()
        OnmcDoctor.objects.bulk_create(objs, batch_size=500)
    logger.info('ONMC scrape stored %s doctors (pages=%s)', len(objs), pages)
    return {'stored': len(objs), 'pages': pages, 'error': err}


@shared_task
def sync_facilities():
    """Refresh the hospital + pharmacy directory from Google Places into the DB.
    Runs weekly via Celery Beat so the admin doesn't have to sync manually."""
    from .views import run_facility_sync
    return run_facility_sync()
