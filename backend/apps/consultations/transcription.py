"""Groq-hosted Whisper transcription for live call captions + report drafting.

Groq runs the same Whisper model as OpenAI (`whisper-large-v3` /
`-turbo`), so accuracy on Clinix's bilingual English/French speech is
identical — it's just faster, cheaper, and has a usable free tier. The
endpoint is OpenAI-compatible, so this is a plain multipart POST.

Used for the per-10s live-caption chunks. Each chunk is a short WAV (one
speaker), which is exactly Whisper's sweet spot.
"""
import logging
import os

import requests

logger = logging.getLogger(__name__)

GROQ_TRANSCRIBE_URL = 'https://api.groq.com/openai/v1/audio/transcriptions'
# Fast + cheap + multilingual. Override with GROQ_STT_MODEL if needed
# (e.g. 'whisper-large-v3' for max accuracy at slightly higher latency).
GROQ_STT_MODEL = os.environ.get('GROQ_STT_MODEL', 'whisper-large-v3-turbo')


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
