"""Groq-vision document reader for provider verification.

Reads a provider's uploaded **National ID** image and **medical-license /
registration** document (image OR PDF) and extracts the identity fields as
structured JSON, so they can be cross-checked against the signup details and
the CMC/ONMC registry.

Why Groq:  same provider + API key already used for Whisper transcription and
report drafting -> "Groq for everything". Groq's multimodal Llama 4 reads the
ID/license image directly. PDFs are first rendered to an image with PyMuPDF.

Everything degrades gracefully: a missing key, unreadable file, missing
PyMuPDF, or a bad API response just yields {} so verification still runs on the
registry match alone. Extracted fields are cached (24h) so re-opening a review
is instant and doesn't re-bill Groq.
"""
import base64
import hashlib
import io
import json
import logging
import os

import requests
from django.core.cache import cache

logger = logging.getLogger(__name__)

GROQ_CHAT_URL = 'https://api.groq.com/openai/v1/chat/completions'
# Multimodal Llama 4 on Groq. Override with GROQ_VISION_MODEL if needed.
GROQ_VISION_MODEL = os.environ.get('GROQ_VISION_MODEL', 'meta-llama/llama-4-scout-17b-16e-instruct')

_CACHE_TTL = 60 * 60 * 24  # 24h

_ID_PROMPT = (
    'You are reading a national identity card. Extract the cardholder details. '
    'Reply with ONLY a JSON object (no markdown, no commentary) in EXACTLY this '
    'shape: {"full_name": "", "id_number": "", "date_of_birth": "", "country": ""}. '
    'Use the exact text printed on the card. "country" is the issuing country '
    '(e.g. "Cameroon"). Use an empty string for any field that is not visible.'
)

_LICENSE_PROMPT = (
    'You are reading a medical practitioner registration / license document. '
    'Extract the details. Reply with ONLY a JSON object (no markdown, no '
    'commentary) in EXACTLY this shape: '
    '{"full_name": "", "registration_number": "", "issuer": "", "specialty": ""}. '
    '"issuer" is the organisation that issued it (e.g. "Ordre National des '
    'Medecins du Cameroun"). Use exact text; empty string if a field is absent.'
)


def _download(url):
    r = requests.get(url, timeout=30)
    r.raise_for_status()
    return r.content, r.headers.get('Content-Type', '')


def _to_image_bytes(raw, content_type, url):
    """Return (image_bytes, mime). Renders the first page of a PDF to PNG and
    downscales large photos to keep the request small/fast."""
    clean_url = url.lower().split('?', 1)[0]
    is_pdf = raw[:5] == b'%PDF-' or 'pdf' in (content_type or '').lower() or clean_url.endswith('.pdf')
    if is_pdf:
        import fitz  # PyMuPDF
        doc = fitz.open(stream=raw, filetype='pdf')
        pix = doc.load_page(0).get_pixmap(dpi=150)
        return pix.tobytes('png'), 'image/png'
    # Downscale phone photos so the base64 payload stays small.
    try:
        from PIL import Image
        im = Image.open(io.BytesIO(raw)).convert('RGB')
        im.thumbnail((1600, 1600))
        buf = io.BytesIO()
        im.save(buf, format='JPEG', quality=85)
        return buf.getvalue(), 'image/jpeg'
    except Exception:
        return raw, (content_type or 'image/jpeg')


def _parse_json(text: str) -> dict:
    text = (text or '').strip()
    if '```' in text:
        if '```json' in text:
            text = text.split('```json', 1)[1].split('```', 1)[0].strip()
        else:
            text = text.split('```', 1)[1].split('```', 1)[0].strip()
    try:
        data = json.loads(text)
        return data if isinstance(data, dict) else {}
    except Exception:
        logger.warning('Vision extract: could not parse JSON: %s', text[:200])
        return {}


def _vision_extract(image_bytes, mime, prompt) -> dict:
    api_key = os.environ.get('GROQ_API_KEY', '').strip()
    if not api_key or not image_bytes:
        return {}
    b64 = base64.b64encode(image_bytes).decode()
    try:
        resp = requests.post(
            GROQ_CHAT_URL,
            headers={'Authorization': f'Bearer {api_key}'},
            json={
                'model': GROQ_VISION_MODEL,
                'temperature': 0,
                'messages': [{
                    'role': 'user',
                    'content': [
                        {'type': 'text', 'text': prompt},
                        {'type': 'image_url', 'image_url': {'url': f'data:{mime};base64,{b64}'}},
                    ],
                }],
            },
            timeout=60,
        )
    except Exception:
        logger.exception('Groq vision request failed')
        return {}
    if resp.status_code != 200:
        logger.warning('Groq vision %s: %s', resp.status_code, resp.text[:300])
        return {}
    try:
        content = resp.json()['choices'][0]['message']['content']
    except Exception:
        logger.exception('Groq vision: unexpected response shape')
        return {}
    return _parse_json(content)


def extract_document(document_url: str, document_type: str) -> dict:
    """Download a credential and extract its identity fields with Groq vision.
    Cached by (type, url). Returns {} on any failure so callers degrade
    gracefully to a registry-only check."""
    if not document_url:
        return {}
    key = 'docx:' + hashlib.sha1(f'{document_type}|{document_url}'.encode()).hexdigest()
    cached = cache.get(key)
    if cached is not None:
        return cached

    result = {}
    try:
        raw, ct = _download(document_url)
        image_bytes, mime = _to_image_bytes(raw, ct, document_url)
        prompt = _LICENSE_PROMPT if document_type == 'medical_license' else _ID_PROMPT
        result = _vision_extract(image_bytes, mime, prompt)
    except Exception:
        logger.exception('extract_document failed for %s', document_url)
        result = {}

    cache.set(key, result, _CACHE_TTL)
    return result
