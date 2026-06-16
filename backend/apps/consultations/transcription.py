"""Groq-hosted Whisper transcription for live call captions + report drafting.

Groq runs the same Whisper model as OpenAI (`whisper-large-v3` /
`-turbo`), so accuracy on Clinix's bilingual English/French speech is
identical — it's just faster, cheaper, and has a usable free tier. The
endpoint is OpenAI-compatible, so this is a plain multipart POST.

Used for the per-10s live-caption chunks. Each chunk is a short WAV (one
speaker), which is exactly Whisper's sweet spot.
"""
import json
import logging
import os

import requests

logger = logging.getLogger(__name__)

GROQ_TRANSCRIBE_URL = 'https://api.groq.com/openai/v1/audio/transcriptions'
GROQ_CHAT_URL = 'https://api.groq.com/openai/v1/chat/completions'
# Fast + cheap + multilingual. Override with GROQ_STT_MODEL if needed
# (e.g. 'whisper-large-v3' for max accuracy at slightly higher latency).
GROQ_STT_MODEL = os.environ.get('GROQ_STT_MODEL', 'whisper-large-v3-turbo')
# Chat model used to draft the medical record from the transcript.
GROQ_CHAT_MODEL = os.environ.get('GROQ_CHAT_MODEL', 'llama-3.3-70b-versatile')


def groq_transcribe(audio_bytes: bytes, filename: str = 'audio.wav',
                    language: str | None = None) -> str:
    """Transcribe a short audio clip with Groq Whisper. Returns plain text,
    or '' on any failure (missing key, network, empty audio, API error) so the
    caller can degrade gracefully rather than break the call."""
    api_key = os.environ.get('GROQ_API_KEY', '').strip()
    if not api_key:
        logger.error('GROQ_API_KEY not set; cannot transcribe.')
        return ''
    if not audio_bytes:
        return ''

    data = {
        'model': GROQ_STT_MODEL,
        'response_format': 'text',
        'temperature': '0',
    }
    # Whisper auto-detects language, which is what we want for EN/FR
    # code-switching. Callers can still pin a language for short/noisy chunks.
    if language:
        data['language'] = language

    try:
        resp = requests.post(
            GROQ_TRANSCRIBE_URL,
            headers={'Authorization': f'Bearer {api_key}'},
            files={'file': (filename, audio_bytes, 'audio/wav')},
            data=data,
            timeout=60,
        )
    except Exception:
        logger.exception('Groq transcription request failed')
        return ''

    if resp.status_code != 200:
        logger.warning('Groq STT %s: %s', resp.status_code, resp.text[:300])
        return ''
    # response_format=text → the body IS the transcript.
    return (resp.text or '').strip()


_REPORT_PROMPT = (
    'You are a medical scribe. Read the following CONSULTATION TRANSCRIPT '
    '(lines are labelled [Doctor] and [Patient]) and draft a structured '
    'medical record. Reply with ONLY a valid JSON object (no markdown, no '
    'commentary) in EXACTLY this shape:\n'
    '{"title": "string",'
    ' "chief_complaint": "string",'
    ' "symptoms": ["string"],'
    ' "symptom_duration": "string",'
    ' "examination_findings": "string",'
    ' "diagnosis": "string",'
    ' "treatment_plan": "string",'
    ' "medications_summary": "string",'
    ' "follow_up_date": "YYYY-MM-DD or empty"}\n'
    'Rules:\n'
    '- title: 4-8 words summarising the visit.\n'
    "- chief_complaint: one sentence in the patient's own framing.\n"
    '- symptoms: array of short symptom phrases from the transcript.\n'
    '- symptom_duration: e.g. "3 days", or empty if not mentioned.\n'
    '- examination_findings / diagnosis / treatment_plan / medications_summary: '
    'fill from what the doctor said; leave empty ("") if not covered.\n'
    '- follow_up_date: only if explicitly scheduled, else empty string.\n'
    '- DO NOT invent details. Use the transcript\'s primary language (English or French).\n'
    '\nCONSULTATION TRANSCRIPT:\n'
)

_REPORT_KEYS = (
    'title', 'chief_complaint', 'symptoms', 'symptom_duration',
    'examination_findings', 'diagnosis', 'treatment_plan',
    'medications_summary', 'follow_up_date',
)


def _parse_report(text: str) -> dict:
    text = (text or '').strip()
    if '```' in text:
        if '```json' in text:
            text = text.split('```json', 1)[1].split('```', 1)[0].strip()
        else:
            text = text.split('```', 1)[1].split('```', 1)[0].strip()
    try:
        data = json.loads(text)
    except Exception:
        logger.warning('Groq report: could not parse JSON: %s', text[:200])
        return {}
    if not isinstance(data, dict):
        return {}
    out = {}
    for k in _REPORT_KEYS:
        out[k] = data.get(k, [] if k == 'symptoms' else '')
    if not isinstance(out['symptoms'], list):
        out['symptoms'] = [str(out['symptoms'])] if out['symptoms'] else []
    return out


# The AI call summary is broken into named sections the doctor can edit
# individually in the app. (key, human label) — order is preserved everywhere.
SUMMARY_SECTIONS = [
    ('overview', 'Overview'),
    ('reason_for_visit', 'Reason for Visit'),
    ('history_symptoms', 'History & Symptoms'),
    ('examination_findings', 'Examination & Findings'),
    ('assessment', 'Assessment & Impression'),
    ('plan', 'Plan & Recommendations'),
    ('medications', 'Medications'),
    ('follow_up', 'Follow-up'),
]

_SUMMARY_PROMPT = (
    'You are a medical scribe. Read the CONSULTATION TRANSCRIPT (lines are '
    'labelled [Doctor] and [Patient]) and write a clear, sectioned SUMMARY of '
    'the consultation for the doctor. Reply with ONLY a valid JSON object (no '
    'markdown, no commentary) with EXACTLY these string keys:\n'
    '{"overview": "", "reason_for_visit": "", "history_symptoms": "", '
    '"examination_findings": "", "assessment": "", "plan": "", '
    '"medications": "", "follow_up": ""}\n'
    'Rules:\n'
    '- Each value is a concise NARRATIVE summary of what was actually said for '
    'that part — a few sentences, or short bullet lines starting with "- ". '
    'This is a readable summary, NOT a filled form.\n'
    '- If a part was not covered in the call, set its value to "Not discussed '
    'during this call."\n'
    '- Do NOT invent diagnoses, findings, or medications not in the transcript.\n'
    "- Write in the transcript's primary language (English or French).\n\n"
    'CONSULTATION TRANSCRIPT:\n'
)


def groq_summarize_consultation(transcript: str) -> dict:
    """Summarise the whole call into structured, editable sections (keyed by
    SUMMARY_SECTIONS). NOT the manual report's template fields. Returns {} on
    any failure so the caller can fall back to another model."""
    api_key = os.environ.get('GROQ_API_KEY', '').strip()
    transcript = (transcript or '').strip()
    if not api_key or not transcript:
        return {}
    try:
        resp = requests.post(
            GROQ_CHAT_URL,
            headers={'Authorization': f'Bearer {api_key}'},
            json={
                'model': GROQ_CHAT_MODEL,
                'messages': [
                    {'role': 'system',
                     'content': 'You are a careful medical scribe that outputs only valid JSON '
                                'and never invents clinical details.'},
                    {'role': 'user', 'content': _SUMMARY_PROMPT + transcript[:24000]},
                ],
                'temperature': 0.3,
                'response_format': {'type': 'json_object'},
            },
            timeout=90,
        )
    except Exception:
        logger.exception('Groq summary request failed')
        return {}
    if resp.status_code != 200:
        logger.warning('Groq summary %s: %s', resp.status_code, resp.text[:300])
        return {}
    try:
        content = resp.json()['choices'][0]['message']['content']
        data = json.loads(content)
    except Exception:
        logger.exception('Groq summary: could not parse JSON')
        return {}
    if not isinstance(data, dict):
        return {}
    out = {}
    for key, _label in SUMMARY_SECTIONS:
        val = data.get(key, '')
        if isinstance(val, list):
            val = '\n'.join(f'- {v}' for v in val)
        out[key] = str(val or '').strip()
    return out


def sections_to_markdown(sections: dict) -> str:
    """Render the section dict to markdown for read-only display."""
    if not sections:
        return ''
    parts = []
    for key, label in SUMMARY_SECTIONS:
        val = (sections.get(key) or '').strip()
        if val:
            parts.append(f'## {label}\n\n{val}')
    return '\n\n'.join(parts)


def groq_draft_medical_record(transcript: str) -> dict:
    """Draft a structured medical record from the transcript using a Groq-hosted
    LLM (OpenAI-compatible chat completions). Returns the structured dict, or {}
    on any failure so the caller can fall back to another model."""
    api_key = os.environ.get('GROQ_API_KEY', '').strip()
    transcript = (transcript or '').strip()
    if not api_key or not transcript:
        return {}
    try:
        resp = requests.post(
            GROQ_CHAT_URL,
            headers={'Authorization': f'Bearer {api_key}'},
            json={
                'model': GROQ_CHAT_MODEL,
                'messages': [
                    {'role': 'system',
                     'content': 'You are a careful medical scribe that outputs only valid JSON.'},
                    {'role': 'user', 'content': _REPORT_PROMPT + transcript[:24000]},
                ],
                'temperature': 0.2,
                'response_format': {'type': 'json_object'},
            },
            timeout=90,
        )
    except Exception:
        logger.exception('Groq report request failed')
        return {}
    if resp.status_code != 200:
        logger.warning('Groq report %s: %s', resp.status_code, resp.text[:300])
        return {}
    try:
        content = resp.json()['choices'][0]['message']['content']
    except Exception:
        logger.exception('Groq report: unexpected response shape')
        return {}
    return _parse_report(content)
