"""Autonomous provider verification.

When a provider submits (registers / uploads a credential), this scores them
automatically — no admin click needed — and applies a decision policy:

  * STRONG, non-contradicted match  -> auto-approve (ai_auto_approved=True)
  * everything else                 -> stay pending = escalate to an admin

The document extraction is ALWAYS run on whatever documents the provider
uploaded (it is never bypassed): every credential is sent to Groq vision and
its contents extracted, then cross-checked. The registry-only path only applies
when there are literally no documents.

The result (probability, recommendation, notes) is stored on the provider so
the admin list can show scores without re-running the model.
"""
import logging
import threading

logger = logging.getLogger(__name__)

# Auto-approve only on a strong registry match. Below this, a human decides.
AUTO_APPROVE_THRESHOLD = 0.90


def _name_contradiction(checks):
    """True if a document's name was read and it does NOT match the applicant."""
    return any(
        c.get('status') == 'fail' and 'name' in (c.get('label', '').lower())
        for c in (checks or [])
    )


def assess_and_store(provider):
    """Run the full assessment (registry match + document extraction), store it
    on the provider, and auto-approve if the policy allows. Returns the
    assessment dict."""
    from django.utils import timezone
    from apps.ai_engine.verification import assess_provider
    from apps.ai_engine.document_extraction import extract_document
    from apps.providers.models import ProviderCredential

    user = provider.provider_id
    full_name = getattr(user, 'full_name', '') or ''

    # ALWAYS extract every uploaded document — never skipped.
    creds = list(ProviderCredential.objects.filter(provider=provider))
    extracted = [{
        'document_type': c.document_type,
        'label': c.get_document_type_display(),
        'fields': extract_document(c.document_url, c.document_type),
    } for c in creds]

    result = assess_provider(full_name, provider.license_number or '', extracted)

    prob = float(result.get('match_probability') or 0)
    decision = result.get('overall_decision') or result.get('decision') or 'review'
    contradiction = _name_contradiction(result.get('checks'))

    matched = result.get('matched_registry_entry') or {}
    note_bits = [f'registry match {round(prob * 100)}%']
    if matched.get('name'):
        note_bits.append(f"matched {matched['name']} ({matched.get('registration_number', '')})")
    if creds:
        note_bits.append(f'{len(creds)} document(s) read')
    if contradiction:
        note_bits.append('document name mismatch')

    provider.ai_match_probability = prob
    provider.ai_decision = decision
    provider.ai_checked_at = timezone.now()
    provider.ai_notes = '; '.join(note_bits)

    auto_approved = False
    # Auto-approve requires a document to have been submitted and extracted
    # (extraction is never bypassed), a strong registry match, and no name
    # contradiction. No document -> escalate to a human. Never override an
    # existing human decision (only act while still pending).
    has_docs = len(creds) > 0
    if (provider.verification_status == 'pending' and has_docs
            and prob >= AUTO_APPROVE_THRESHOLD and not contradiction):
        provider.verification_status = 'approved'
        provider.verified_at = timezone.now()
        provider.ai_auto_approved = True
        provider.verification_notes = f'Auto-approved by AI — {provider.ai_notes}'
        auto_approved = True

    provider.save(update_fields=[
        'ai_match_probability', 'ai_decision', 'ai_notes', 'ai_checked_at',
        'ai_auto_approved', 'verification_status', 'verified_at', 'verification_notes',
    ])

    if auto_approved:
        try:
            from apps.notifications.dispatch import notify
            notify(
                str(user.user_id),
                'You are verified',
                'Your provider account has been verified — you can now receive consultations.',
                'verification',
                {'status': 'approved'},
            )
        except Exception:
            logger.warning('auto-verify: provider notify failed', exc_info=True)

    logger.info('auto-verify %s: prob=%.2f decision=%s auto_approved=%s',
                provider.pk, prob, decision, auto_approved)
    return result


def trigger_async(provider_pk):
    """Run assess_and_store on a background thread so submission stays instant."""
    def _work():
        from django.db import connection
        from apps.providers.models import HealthcareProvider
        try:
            provider = HealthcareProvider.objects.select_related('provider_id').get(pk=provider_pk)
            assess_and_store(provider)
        except Exception:
            logger.exception('auto-verify background failed for %s', provider_pk)
        finally:
            connection.close()

    threading.Thread(target=_work, daemon=True).start()
