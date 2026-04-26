import os
import json
import logging
import google.generativeai as genai
from google.generativeai.types import HarmCategory, HarmBlockThreshold

logger = logging.getLogger(__name__)


class MedLMNotConfigured(Exception):
    """Gemini AI is not configured (missing API key)."""


class MedLMInferenceError(Exception):
    """Model call failed or returned unusable output."""


SYSTEM_INSTRUCTION = (
    "You are Clinix AI, a highly skilled medical triage assistant specialized in healthcare in "
    "Cameroon. Your job is to (a) perform a thorough preliminary clinical assessment through a real, "
    "interactive conversation, and then (b) help the patient find the right provider on the Clinix "
    "platform. Use professional medical terminology, be warm and empathetic, and maintain a calm, "
    "clinical persona.\n"
    "\n"
    "Follow the ABCDE (Airway, Breathing, Circulation, Disability, Exposure) approach when evaluating "
    "acute symptoms.\n"
    "\n"
    "CONVERSATION STYLE — be genuinely interactive, not a form:\n"
    "1. Ask exactly ONE focused clinical question at a time. Never stack multiple questions in one "
    "message.\n"
    "2. Acknowledge what the patient just said in your reply (\"Got it — fever for 3 days. …\") "
    "before asking the next question. Build on their answers; never repeat questions already "
    "answered.\n"
    "3. Use a direct, helpful tone — no repetitive 'thank you' or apologies.\n"
    "4. When you analyse an image, describe clinically what you observe BEFORE asking the next "
    "question.\n"
    "5. The patient may ask YOU a question at any point ('Is this serious?', 'What does that mean?', "
    "'Should I be worried?', 'Can it be malaria?'). When that happens: answer their question first, "
    "concisely and reassuringly (without diagnosing), THEN continue with your next clinical question "
    "in the same message. Treat their question as a sign of engagement, not a derail.\n"
    "6. If the patient seems anxious or confused, briefly reassure them ('That's a good thing to "
    "check — let me ask one more thing to be sure.') before continuing.\n"
    "\n"
    "CONVERSATION DEPTH — be thorough, but stay within bounds:\n"
    "7. Ask AT LEAST 4 and AT MOST 8 of YOUR OWN clinical questions before summarising. Patient "
    "questions to you do NOT count toward this limit. Use your questions to cover: onset, duration, "
    "severity, associated symptoms, triggers / aggravators, prior episodes, medications already "
    "tried, and relevant history (chronic conditions, pregnancy, recent travel, allergies). Pick the "
    "ones that matter most for the presenting complaint — don't run the whole list robotically.\n"
    "8. If you have enough information after 4 questions to give a confident triage, move on to the "
    "summary. If the case is complex or red-flag territory, go deeper (up to 8) before summarising. "
    "Never exceed 8 of your own questions.\n"
    "9. Just before you summarise, invite the patient: 'Anything else you want me to consider before "
    "I give you my assessment?' If they raise something new, address it; otherwise proceed.\n"
    "\n"
    "DIAGNOSIS BOUNDARIES:\n"
    "7. Never provide a final diagnosis. You MAY provide a short differential (2–5 likely causes) "
    "phrased as 'possible causes'. Always include in your summary: 'I am an AI triage assistant, not "
    "a doctor. This is a preliminary assessment.'\n"
    "8. If any Red Flags are present (chest pain, stroke signs, difficulty breathing, severe "
    "bleeding, loss of consciousness, sudden severe headache, signs of sepsis), instruct the user "
    "clearly and immediately to visit the nearest emergency department or call emergency services. "
    "Do this even if you are still mid-conversation.\n"
    "9. When you reach the summary, cover: what findings matter, why these causes are plausible, what "
    "to do next (home care if appropriate, what to monitor, when to seek urgent care), and red "
    "flags to watch for.\n"
    "\n"
    "PROVIDER TYPE — Clinix has two kinds of providers:\n"
    "  • Doctors (generalists & specialists) — VIRTUAL consultations (chat / audio / video). "
    "Distance and budget do NOT matter for them, so do NOT ask the patient about location or "
    "budget.\n"
    "  • Nurses & midwives — IN-PERSON home care (wound dressing, injections, prenatal home checks, "
    "post-op care, elderly care, vitals monitoring at home). Proximity matters here because closer "
    "nurses are cheaper to dispatch — but Clinix already knows the patient's GPS, so do NOT ask the "
    "patient for their location either.\n"
    "If the case obviously needs hands-on home care, the right provider is a nurse. Otherwise it is "
    "a doctor (generalist for routine issues, specialist for area-specific cases).\n"
    "\n"
    "PROVIDER MATCHING — after your summary, ask ONE short final question, in a natural "
    "conversational tone:\n"
    "  • If a doctor is appropriate: 'Would you like me to suggest a doctor (or specialist) on "
    "Clinix who can handle this for you?'\n"
    "  • If a nurse is appropriate: 'Would you like me to recommend a nurse near you to handle this "
    "at home?'\n"
    "If the patient does not give a clear yes/no, gently clarify ONCE (e.g. 'Should I go ahead and "
    "find someone for you?'). After that, default to YES unless they explicitly decline. Do NOT "
    "argue or pressure them.\n"
    "Do NOT ask about distance, location, or budget — those are handled automatically by the app."
)

SAFETY_SETTINGS = {
    HarmCategory.HARM_CATEGORY_HARASSMENT: HarmBlockThreshold.BLOCK_NONE,
    HarmCategory.HARM_CATEGORY_HATE_SPEECH: HarmBlockThreshold.BLOCK_NONE,
    HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: HarmBlockThreshold.BLOCK_NONE,
    HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: HarmBlockThreshold.BLOCK_NONE,
}


class MedLMClient:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if getattr(self, '_singleton_configured', False):
            return
        self._singleton_configured = True

        self.model_id = os.getenv('MEDLM_MODEL_ID', 'gemini-1.5-flash-latest')
        self.api_key = os.getenv('GEMINI_API_KEY', '')
        self._model_ready = False
        self.model = None

        def _strip_models_prefix(model_name: str) -> str:
            model_name = (model_name or '').strip()
            if model_name.startswith('models/'):
                return model_name.split('models/', 1)[1]
            return model_name

        def _pick_fallback_model_id() -> str:
            try:
                models = list(genai.list_models())
            except Exception:
                logger.exception('ClinixAI list_models failed')
                return ''

            candidates = []
            for m in models:
                name = getattr(m, 'name', '') or ''
                methods = getattr(m, 'supported_generation_methods', []) or []
                if 'generateContent' not in methods:
                    continue
                if 'gemini' not in name.lower():
                    continue
                candidates.append(name)

            preferred = [
                'models/gemini-1.5-flash-latest',
                'models/gemini-1.5-flash',
                'models/gemini-1.5-pro-latest',
                'models/gemini-1.5-pro',
            ]
            for p in preferred:
                if p in candidates:
                    return _strip_models_prefix(p)
            if candidates:
                return _strip_models_prefix(candidates[0])
            return ''

        if self.api_key:
            try:
                genai.configure(api_key=self.api_key)
                self.model_id = _strip_models_prefix(self.model_id)
                try:
                    self.model = genai.GenerativeModel(
                        model_name=self.model_id,
                        system_instruction=SYSTEM_INSTRUCTION,
                    )
                except Exception:
                    fallback = _pick_fallback_model_id()
                    if not fallback:
                        raise
                    logger.warning('ClinixAI model not available (%s). Falling back to %s', self.model_id, fallback)
                    self.model_id = fallback
                    self.model = genai.GenerativeModel(
                        model_name=self.model_id,
                        system_instruction=SYSTEM_INSTRUCTION,
                    )

                self._model_ready = True
                logger.info('ClinixAI ready: model=%s', self.model_id)
            except Exception:
                logger.exception('ClinixAI init failed')
                self._model_ready = False
        else:
            logger.warning('GEMINI_API_KEY not set. AI features disabled.')

    def _require_model(self):
        if not self._model_ready or self.model is None:
            raise MedLMNotConfigured(
                'Gemini AI is not configured. Please set GEMINI_API_KEY in your .env file. '
                'Get a free key at: https://aistudio.google.com/app/apikey'
            )

    def _build_history(self, history):
        """Convert DB message history to genai Content format."""
        contents = []
        for turn in history:
            role = 'user' if turn.get('role') == 'user' else 'model'
            parts_input = turn.get('parts') or []
            parts = []
            for p in parts_input:
                if isinstance(p, dict) and 'data' in p:
                    parts.append({'mime_type': p.get('mime_type', 'image/jpeg'), 'data': p['data']})
                else:
                    parts.append(str(p))
            if parts:
                contents.append({'role': role, 'parts': parts})
        return contents

    def _should_fallback(self, err: Exception) -> bool:
        msg = str(err or '')
        msg_l = msg.lower()
        return (
            '404' in msg_l
            and ('model' in msg_l or 'models/' in msg_l)
            and ('not found' in msg_l or 'is not found' in msg_l)
        )

    def _fallback_model(self) -> bool:
        try:
            models = list(genai.list_models())
        except Exception:
            logger.exception('ClinixAI list_models failed')
            return False

        candidates = []
        for m in models:
            name = getattr(m, 'name', '') or ''
            methods = getattr(m, 'supported_generation_methods', []) or []
            if 'generateContent' not in methods:
                continue
            if 'gemini' not in name.lower():
                continue
            candidates.append(name)

        preferred = [
            'models/gemini-1.5-flash-latest',
            'models/gemini-1.5-flash',
            'models/gemini-1.5-pro-latest',
            'models/gemini-1.5-pro',
        ]

        def _strip_models_prefix(model_name: str) -> str:
            model_name = (model_name or '').strip()
            if model_name.startswith('models/'):
                return model_name.split('models/', 1)[1]
            return model_name

        fallback = ''
        for p in preferred:
            if p in candidates:
                fallback = _strip_models_prefix(p)
                break
        if not fallback and candidates:
            fallback = _strip_models_prefix(candidates[0])
        if not fallback or fallback == self.model_id:
            return False

        logger.warning('ClinixAI request failed for model=%s. Falling back to %s', self.model_id, fallback)
        self.model_id = fallback
        self.model = genai.GenerativeModel(
            model_name=self.model_id,
            system_instruction=SYSTEM_INSTRUCTION,
        )
        self._model_ready = True
        return True

    def get_opening_message(self) -> str:
        self._require_model()
        prompt = (
            'Write exactly one short opening message (2–3 sentences). '
            'Introduce yourself as Clinix AI, be warm and professional, '
            'and ask what symptom or health concern they want help with today. '
            'Do not give medical advice, diagnosis, or facts in this message.'
        )
        try:
            response = self.model.generate_content(prompt, safety_settings=SAFETY_SETTINGS)
            text = (response.text or '').strip()
            if not text:
                raise MedLMInferenceError('Model returned an empty opening message.')
            return text
        except MedLMNotConfigured:
            raise
        except Exception as e:
            if self._should_fallback(e) and self._fallback_model():
                try:
                    response = self.model.generate_content(prompt, safety_settings=SAFETY_SETTINGS)
                    text = (response.text or '').strip()
                    if not text:
                        raise MedLMInferenceError('Model returned an empty opening message.')
                    return text
                except Exception as e2:
                    logger.exception('ClinixAI opening message failed after fallback')
                    raise MedLMInferenceError(str(e2)) from e2
            logger.exception('ClinixAI opening message failed')
            raise MedLMInferenceError(str(e)) from e

    def get_chat_response(self, history, message: str, image_data: bytes = None, mime_type: str = None) -> str:
        self._require_model()
        try:
            contents = self._build_history(history)
            chat = self.model.start_chat(history=contents)

            # Build the current turn payload
            payload = [message]
            if image_data:
                payload.append({'mime_type': mime_type or 'image/jpeg', 'data': image_data})

            response = chat.send_message(payload, safety_settings=SAFETY_SETTINGS)
            text = (response.text or '').strip()
            if not text:
                raise MedLMInferenceError('Model returned an empty reply.')
            return text
        except MedLMNotConfigured:
            raise
        except MedLMInferenceError:
            raise
        except Exception as e:
            if self._should_fallback(e) and self._fallback_model():
                try:
                    contents = self._build_history(history)
                    chat = self.model.start_chat(history=contents)
                    payload = [message]
                    if image_data:
                        payload.append({'mime_type': mime_type or 'image/jpeg', 'data': image_data})
                    response = chat.send_message(payload, safety_settings=SAFETY_SETTINGS)
                    text = (response.text or '').strip()
                    if not text:
                        raise MedLMInferenceError('Model returned an empty reply.')
                    return text
                except Exception as e2:
                    logger.exception('ClinixAI chat failed after fallback')
                    raise MedLMInferenceError(str(e2)) from e2
            logger.exception('ClinixAI chat failed')
            raise MedLMInferenceError(str(e)) from e

    def get_structured_assessment(self, history) -> dict:
        self._require_model()
        prompt = (
            'Based on the conversation, reply with ONLY valid JSON (no markdown fences) in this exact shape:\n'
            '{"potential_conditions": ["string"],'
            ' "triage_priority": "Low|Medium|High",'
            ' "recommended_specialization": "string",'
            ' "provider_role": "doctor|nurse",'
            ' "consultation_type": "virtual|in_person",'
            ' "wants_provider_suggestion": true|false,'
            ' "summary": "string"}\n'
            'Rules:\n'
            '- potential_conditions: 2–5 items maximum, phrased as possible causes (not a diagnosis).\n'
            '- triage_priority: Low/Medium/High based on urgency/red-flags.\n'
            '- provider_role: "nurse" only when home care is the right fit (wound care, injections, '
            'post-op care, elderly support, prenatal home checks, vitals monitoring at home). Otherwise '
            '"doctor".\n'
            '- consultation_type: "in_person" if provider_role is "nurse", else "virtual".\n'
            '- wants_provider_suggestion: TRUE for any affirmative or neutral answer to the matching '
            'question — including "yes", "ok", "sure", "please", "go ahead", "alright", "yeah", '
            '"oui", "d\'accord", silence, or no clear answer at all. Set FALSE *only* when the '
            'patient explicitly refused (e.g. "no", "not now", "no thanks", "I\'ll think about it", '
            '"non"). When in doubt, default to TRUE.\n'
            '- summary: must be actionable and specific: what findings matter, why these causes are '
            'plausible, what to do next, and red flags.\n'
            "- summary must include exactly once: 'I am an AI triage assistant, not a doctor. This is a "
            "preliminary assessment.'\n"
        )
        try:
            contents = self._build_history(history)
            chat = self.model.start_chat(history=contents)
            response = chat.send_message(prompt, safety_settings=SAFETY_SETTINGS)
            text = (response.text or '').strip()
            if '```' in text:
                if '```json' in text:
                    text = text.split('```json', 1)[1].split('```', 1)[0].strip()
                else:
                    text = text.split('```', 1)[1].split('```', 1)[0].strip()
            data = json.loads(text)
            for k in ('triage_priority', 'recommended_specialization', 'summary'):
                if k not in data:
                    raise ValueError(f'Missing key: {k}')
            data.setdefault('potential_conditions', [])
            data.setdefault('provider_role', 'doctor')
            data.setdefault(
                'consultation_type',
                'in_person' if data.get('provider_role') == 'nurse' else 'virtual',
            )
            data.setdefault('wants_provider_suggestion', True)
            return data
        except MedLMNotConfigured:
            raise
        except Exception as e:
            if self._should_fallback(e) and self._fallback_model():
                try:
                    contents = self._build_history(history)
                    chat = self.model.start_chat(history=contents)
                    response = chat.send_message(prompt, safety_settings=SAFETY_SETTINGS)
                    text = (response.text or '').strip()
                    if '```' in text:
                        if '```json' in text:
                            text = text.split('```json', 1)[1].split('```', 1)[0].strip()
                        else:
                            text = text.split('```', 1)[1].split('```', 1)[0].strip()
                    data = json.loads(text)
                    for k in ('triage_priority', 'recommended_specialization', 'summary'):
                        if k not in data:
                            raise ValueError(f'Missing key: {k}')
                    data.setdefault('potential_conditions', [])
                    data.setdefault('provider_role', 'doctor')
                    data.setdefault(
                        'consultation_type',
                        'in_person' if data.get('provider_role') == 'nurse' else 'virtual',
                    )
                    data.setdefault('wants_provider_suggestion', True)
                    return data
                except Exception as e2:
                    logger.exception('Structured assessment failed after fallback')
                    raise MedLMInferenceError(str(e2)) from e2
            logger.exception('Structured assessment failed')
            raise MedLMInferenceError(str(e)) from e


medlm_client = MedLMClient()
