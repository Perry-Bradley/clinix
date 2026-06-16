"""AI provider verification — an autonomous record-linkage model.

WHAT THIS IS (in ML terms)
--------------------------
* Learning type:  SUPERVISED LEARNING -> binary classification, in the
  sub-field of *record linkage / entity resolution*. The question the model
  answers is: "is the person who signed up the SAME person as a real entry in
  the official CMC/ONMC registry?" -> match (1) / no-match (0).
* Labels:  we do NOT hand-label anything. Training pairs are generated
  automatically from the registry itself (this is "distant / weak
  supervision"). A doctor compared against their own registry row is a
  positive; compared against a different row is a negative.
* Model:  Logistic Regression (scikit-learn) over a handful of string-
  similarity features. It is the classic, interpretable choice for record
  linkage and outputs a calibrated probability (0..1) we surface as a %.
  If scikit-learn / training is unavailable for any reason we fall back to a
  deterministic weighted score so the endpoint never breaks.

INPUTS
------
The provider's *signup* details:  full name + license / registration number.
Reference data:  apps.admin_dashboard.models.OnmcDoctor (the scraped CMC list).

OUTPUT
------
verify_provider(full_name, license_number) -> {
    match_probability, decision (approve|review|reject), summary,
    matched_registry_entry, candidates_checked, model
}
"""
import re
import logging
import unicodedata

logger = logging.getLogger(__name__)

# Module-level model cache. Values:
#   None  -> not trained yet
#   False -> training unavailable, use the deterministic heuristic
#   else  -> a fitted scikit-learn estimator
_MODEL = None

# Decision thresholds on the match probability.
_APPROVE_THRESHOLD = 0.85   # >= -> auto-approve (strong registry match)
_REVIEW_THRESHOLD = 0.50    # >= -> escalate to a human reviewer
# below _REVIEW_THRESHOLD -> auto-reject (no plausible registry match)


# ─── Feature engineering ─────────────────────────────────────────────────────

def _norm(s: str) -> str:
    """Lower-case, strip accents and punctuation, collapse whitespace."""
    s = (s or '').strip().lower()
    s = ''.join(c for c in unicodedata.normalize('NFKD', s) if not unicodedata.combining(c))
    s = re.sub(r'[^a-z0-9 ]', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def _name_similarity(a: str, b: str) -> float:
    """0..1 similarity between two names. token_sort_ratio handles word
    reordering ("First Last" vs "Last First") which is common across registries."""
    na, nb = _norm(a), _norm(b)
    if not na or not nb:
        return 0.0
    try:
        from rapidfuzz import fuzz
        return fuzz.token_sort_ratio(na, nb) / 100.0
    except Exception:
        from difflib import SequenceMatcher
        # Sort tokens ourselves so difflib is order-insensitive too.
        return SequenceMatcher(None, ' '.join(sorted(na.split())),
                               ' '.join(sorted(nb.split()))).ratio()


def _digits(s: str) -> str:
    return re.sub(r'\D', '', s or '')


def _reg_features(license_no: str, registry_reg: str):
    """Return (exact_match, digits_match, digit_similarity) comparing the
    signup license number against a registry registration number. CMC numbers
    look like '13574/2024'; providers may type them many ways, so we compare
    both the raw normalised string and the digits-only form."""
    l, r = _norm(license_no), _norm(registry_reg)
    exact = 1.0 if l and l == r else 0.0
    ld, rd = _digits(license_no), _digits(registry_reg)
    digits_match = 1.0 if ld and rd and (ld == rd or ld in rd or rd in ld) else 0.0
    from difflib import SequenceMatcher
    digit_sim = SequenceMatcher(None, ld, rd).ratio() if (ld and rd) else 0.0
    return exact, digits_match, digit_sim


def _features(prov_name, prov_lic, entry_name, entry_reg):
    """Feature vector for one (applicant, registry-entry) pair."""
    name_sim = _name_similarity(prov_name, entry_name)
    reg_exact, reg_digits, reg_sim = _reg_features(prov_lic, entry_reg)
    return [name_sim, reg_exact, reg_digits, reg_sim]


# ─── Model training (distant supervision from the registry) ──────────────────

def _perturb_name(name: str) -> str:
    """Make a realistic 'applicant typed it differently' variant of a name:
    reorder the tokens (e.g. surname first). Teaches the model that name order
    shouldn't break a match."""
    import random
    toks = (name or '').split()
    if len(toks) > 1:
        random.shuffle(toks)
    return ' '.join(toks)


def _build_training_set(limit=4000, sample=1500):
    """Auto-generate labelled (features, label) pairs from the CMC registry.

    Positives: a doctor matched against their OWN row (exact + reordered name).
    Negatives: a doctor matched against a DIFFERENT random row.
    No manual labelling required -> distant supervision.
    """
    import random
    from apps.admin_dashboard.models import OnmcDoctor

    rows = list(
        OnmcDoctor.objects.exclude(name='')
        .values_list('name', 'registration_number')[:limit]
    )
    if len(rows) < 50:
        return None, None

    random.shuffle(rows)
    n = len(rows)
    X, y = [], []
    for name, reg in rows[:sample]:
        # POSITIVES — same person
        X.append(_features(name, reg, name, reg)); y.append(1)
        X.append(_features(_perturb_name(name), reg, name, reg)); y.append(1)
        # NEGATIVES — different person
        on, oreg = rows[random.randrange(n)]
        X.append(_features(name, reg, on, oreg)); y.append(0)
        on2, oreg2 = rows[random.randrange(n)]
        X.append(_features(_perturb_name(name), reg, on2, oreg2)); y.append(0)
    return X, y


def _get_model():
    global _MODEL
    if _MODEL is not None:
        return _MODEL
    try:
        from sklearn.linear_model import LogisticRegression
        X, y = _build_training_set()
        if not X:
            logger.warning('Verification model: not enough registry data; using heuristic.')
            _MODEL = False
        else:
            _MODEL = LogisticRegression(max_iter=1000).fit(X, y)
            logger.info('Verification model trained on %d auto-labelled pairs.', len(X))
    except Exception:
        logger.exception('Verification model training failed; using heuristic.')
        _MODEL = False
    return _MODEL


def reset_model():
    """Clear the cached model so the next call retrains (e.g. after a re-scrape)."""
    global _MODEL
    _MODEL = None


def _heuristic_score(feats):
    name_sim, reg_exact, reg_digits, reg_sim = feats
    score = 0.55 * name_sim + 0.25 * reg_exact + 0.15 * reg_digits + 0.05 * reg_sim
    return max(0.0, min(1.0, score))


def _score(feats):
    model = _get_model()
    if not model:  # False or None
        return _heuristic_score(feats)
    try:
        return float(model.predict_proba([feats])[0][1])
    except Exception:
        return _heuristic_score(feats)


# ─── Inference ───────────────────────────────────────────────────────────────

def _candidate_entries(full_name, license_number, cap=300):
    """Blocking step: pull a small candidate set instead of scoring all ~12k
    rows. We block on shared name tokens OR matching registration digits."""
    from django.db.models import Q
    from apps.admin_dashboard.models import OnmcDoctor

    q = Q()
    for tok in [t for t in _norm(full_name).split() if len(t) > 2][:3]:
        q |= Q(name__icontains=tok)
    digits = _digits(license_number)
    if len(digits) >= 3:
        q |= Q(registration_number__icontains=digits)
    if not q:
        return []
    return list(OnmcDoctor.objects.filter(q)[:cap])


def verify_provider(full_name: str, license_number: str) -> dict:
    """Score how confidently a provider's signup details match the CMC registry
    and return an autonomous decision."""
    full_name = (full_name or '').strip()
    license_number = (license_number or '').strip()

    candidates = _candidate_entries(full_name, license_number)

    best = {'probability': 0.0, 'name': None, 'registration_number': None,
            'specialization': None, 'features': None}
    for e in candidates:
        feats = _features(full_name, license_number, e.name, e.registration_number)
        p = _score(feats)
        if p > best['probability']:
            best = {
                'probability': p, 'name': e.name,
                'registration_number': e.registration_number,
                'specialization': getattr(e, 'specialization', ''),
                'features': feats,
            }

    prob = round(best['probability'], 4)
    if prob >= _APPROVE_THRESHOLD:
        decision, summary = 'approve', 'Strong match found in the CMC registry.'
    elif prob >= _REVIEW_THRESHOLD:
        decision, summary = 'review', 'Partial match — recommend human review.'
    else:
        decision, summary = 'reject', 'No matching record found in the CMC registry.'

    feats = best['features'] or [0, 0, 0, 0]
    return {
        'match_probability': prob,
        'match_percent': round(prob * 100, 1),
        'decision': decision,
        'summary': summary,
        'matched_registry_entry': (
            {
                'name': best['name'],
                'registration_number': best['registration_number'],
                'specialization': best['specialization'],
            } if best['name'] else None
        ),
        'signals': {
            'name_similarity': round(feats[0], 3),
            'reg_number_exact': bool(feats[1]),
            'reg_number_digits_match': bool(feats[2]),
        },
        'candidates_checked': len(candidates),
        'thresholds': {'approve': _APPROVE_THRESHOLD, 'review': _REVIEW_THRESHOLD},
        'model': 'logistic_regression' if _get_model() else 'heuristic',
    }


# ─── Document cross-checking (fuses registry match + uploaded documents) ──────

_NAME_OK = 0.80  # name-similarity threshold to count two names as the same person


def assess_provider(full_name: str, license_number: str, extracted_docs) -> dict:
    """Full autonomous assessment: the registry record-linkage match PLUS
    cross-checks of the data extracted from the uploaded National ID and
    medical-license documents.

    `extracted_docs` is a list of
        {'document_type': str, 'label': str, 'fields': {...}}
    where `fields` is what document_extraction.extract_document() returned.

    The idea: a fraudster has to make the signup details, BOTH documents AND the
    official registry all agree — far harder than faking one image. We never try
    to detect a forged pixel; we verify by triangulation.
    """
    result = verify_provider(full_name, license_number)
    entry = result.get('matched_registry_entry') or {}
    prob = float(result.get('match_probability') or 0)
    matched_label = entry.get('name') or 'no registry match'

    def fields_for(*types):
        for d in (extracted_docs or []):
            if d.get('document_type') in types:
                return d.get('fields') or {}
        return {}

    id_fields = fields_for('national_id_front', 'national_id_back')
    lic_fields = fields_for('medical_license')

    id_name = (id_fields.get('full_name') or '').strip()
    lic_name = (lic_fields.get('full_name') or '').strip()
    lic_reg = (lic_fields.get('registration_number') or '').strip()
    id_country = (id_fields.get('country') or '').strip()
    lic_issuer = (lic_fields.get('issuer') or '').strip()

    checks = []

    def add(label, status, detail=''):
        checks.append({'label': label, 'status': status, 'detail': detail})

    # Cross-check the SIGNUP full name + SIGNUP license number against the three
    # independent sources: the ID upload, the licence PDF, and the CMC registry.

    # 1) Signup name vs ID upload
    if id_name:
        s = _name_similarity(id_name, full_name)
        add('Signup name matches National ID', 'pass' if s >= _NAME_OK else 'fail',
            f'ID: "{id_name}" ({int(round(s * 100))}%)')
    else:
        add('Signup name matches National ID', 'unknown', 'No National ID provided / unreadable')

    # 2) Signup name vs licence PDF/document
    if lic_name:
        s = _name_similarity(lic_name, full_name)
        add('Signup name matches license document', 'pass' if s >= _NAME_OK else 'fail',
            f'Document: "{lic_name}" ({int(round(s * 100))}%)')
    else:
        add('Signup name matches license document', 'unknown', 'No license document / unreadable')

    # 3) Signup license number vs the number printed on the licence document
    if lic_reg:
        d_lic, d_sign = _digits(lic_reg), _digits(license_number)
        ok = bool(d_lic and d_sign and (d_lic == d_sign or d_lic in d_sign or d_sign in d_lic))
        add('Signup license matches license document', 'pass' if ok else 'fail',
            f'Signup: {license_number or "—"} · Document: {lic_reg}')
    else:
        add('Signup license matches license document', 'unknown', 'Not found on document')

    # 4) Signup details found in the CMC / ONMC medical council registry
    if prob >= _APPROVE_THRESHOLD:
        add('Found in CMC medical council registry', 'pass',
            f'{matched_label} ({int(round(prob * 100))}%)')
    elif prob < _REVIEW_THRESHOLD:
        add('Found in CMC medical council registry', 'fail',
            f'No matching record ({int(round(prob * 100))}%)')
    else:
        add('Found in CMC medical council registry', 'unknown',
            f'Possible match ({int(round(prob * 100))}%)')

    # 5) National ID is Cameroonian
    if id_country:
        ok = 'camero' in id_country.lower() or 'cmr' in id_country.lower()
        add('National ID is Cameroonian', 'pass' if ok else 'fail', id_country)
    else:
        add('National ID is Cameroonian', 'unknown', '')

    # 5) License issued by a medical authority
    if lic_issuer:
        low = lic_issuer.lower()
        ok = any(k in low for k in ['onmc', 'ordre', 'medic', 'medec', 'médec',
                                    'council', 'conseil', 'health', 'sante', 'santé'])
        add('License issued by a medical authority', 'pass' if ok else 'fail', lic_issuer)
    else:
        add('License issued by a medical authority', 'unknown', '')

    passed = sum(1 for c in checks if c['status'] == 'pass')
    failed = sum(1 for c in checks if c['status'] == 'fail')
    name_contradiction = any(c['status'] == 'fail' and 'name' in c['label'].lower() for c in checks)

    # Fusion rule: auto-approve needs a strong registry match AND consistent
    # documents; a name contradiction or multiple failures forces a reject;
    # everything else routes to a human.
    reg_decision = result.get('decision')
    if reg_decision == 'approve' and not name_contradiction and failed == 0 and passed >= 2:
        overall, summary = 'approve', 'Registry match confirmed and uploaded documents are consistent.'
    elif reg_decision == 'reject' or name_contradiction or failed >= 2:
        overall, summary = 'reject', 'Documents and/or registry do not corroborate this identity.'
    else:
        overall, summary = 'review', 'Mixed signals — manual review recommended.'

    result['documents'] = [
        {'document_type': d.get('document_type'), 'label': d.get('label'),
         'fields': d.get('fields') or {}}
        for d in (extracted_docs or [])
    ]
    result['checks'] = checks
    result['checks_passed'] = passed
    result['checks_failed'] = failed
    result['overall_decision'] = overall
    result['overall_summary'] = summary
    return result
