"""AI provider verification — scoring & recommendation only.

When a provider submits (registers / uploads a credential), this scores them
automatically in the background and stores the result. It NEVER approves a
provider or changes their verification status: the AI only produces a match
probability + a recommendation (approve / review / reject), and an admin always
makes the final decision manually.

The document extraction is ALWAYS run on whatever documents the provider
uploaded (it is never bypassed): every credential is sent to Groq vision and
its contents extracted, then cross-checked. The registry-only signal applies
when there are no documents.

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
    provider.ai_decision = decision          # AI RECOMMENDATION only
    provider.ai_checked_at = timezone.now()
    provider.ai_notes = '; '.join(note_bits)

    # IMPORTANT: the AI only SCORES and RECOMMENDS. It NEVER approves a provider
    # or changes their verification status — an admin reviews the confidence
    # score and the document cross-checks and makes the final decision manually.
    provider.ai_auto_approved = False
    provider.save(update_fields=[
        'ai_match_probability', 'ai_decision', 'ai_notes', 'ai_checked_at',
        'ai_auto_approved',
    ])

    logger.info('auto-verify (recommend-only) %s: prob=%.2f recommendation=%s',
                provider.pk, prob, decision)
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
