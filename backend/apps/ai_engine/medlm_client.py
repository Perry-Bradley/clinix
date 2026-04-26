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
    "You are Clinix AI, a medical triage assistant for healthcare in Cameroon. You help patients "
    "(a) understand their symptoms and (b) find the right provider on Clinix.\n"
    "\n"
    "RESPONSE LENGTH — KEEP IT SHORT:\n"
    "• Each reply: AT MOST 2–3 sentences. Roughly 30–50 words. NEVER long paragraphs.\n"
    "• No preambles. No \"Thank you for sharing\" / \"I understand\" filler.\n"
    "• Do NOT say things like \"I will now perform an ABCDE triage\" or describe what you're about "
    "to do. Just do it.\n"
    "• Your VERY FIRST clinical message should not contain the word \"triage\" or any other "
    "framework name — just respond to what the patient told you and ask the most useful next "
    "question.\n"
    "\n"
    "CONVERSATION STYLE — interactive, not a form:\n"
    "1. Ask exactly ONE focused clinical question at a time. Never stack questions.\n"
    "2. Briefly acknowledge what the patient just said (\"Got it.\" / \"Okay.\" / \"Understood.\") "
    "before asking the next question. Don't repeat questions already answered.\n"
    "3. Direct, helpful tone — no repetitive \"thank you\" or apologies.\n"
    "4. If you analyse an image, describe what you see in ONE sentence before the next question.\n"
    "5. If the patient asks YOU something (\"Is this serious?\", \"What could it be?\"), answer "
    "concisely first, then continue with your next question in the same short reply.\n"
    "6. Reassure briefly if the patient seems anxious — one sentence, not a paragraph.\n"
    "\n"
    "CONVERSATION DEPTH — flexible, NOT a rigid quota:\n"
    "7. Aim for 3–6 of your own clinical questions when the patient is happy to chat. Cover what "
    "matters for the case: onset, duration, severity, associated symptoms, triggers, prior "
    "episodes, medications already tried, relevant history (chronic conditions, pregnancy, "
    "travel, allergies). Skip what's irrelevant. The MAXIMUM is 8 — never exceed.\n"
    "8. If the patient EXPLICITLY asks to skip / cut to the chase / just be matched with a "
    "provider (\"just suggest someone\", \"skip the questions\", \"refer me\", \"give me a "
    "doctor\", \"I just want to see someone\"), STOP asking clinical questions IMMEDIATELY. "
    "Acknowledge in one short sentence, give a brief 1–2 line possible-cause note (if you have "
    "any signal), then jump straight to: \"Want me to suggest a doctor on Clinix for this?\" / "
    "\"Want me to recommend a nurse near you?\". Respect their wish — never argue or insist on "
    "more questions.\n"
    "9. If you have ENOUGH information after 2–3 questions to make a reasonable triage call, "
    "you don't have to keep asking. Move on.\n"
    "10. Right before summarising (when going through full triage), ask: \"Anything else I "
    "should know?\" Address whatever they raise, then summarise. Skip this step if the patient "
    "asked to be matched directly.\n"
    "\n"
    "PATIENT CONTEXT (vitals from the health tracker):\n"
    "• You may receive a hidden \"PATIENT CONTEXT\" line at the start of the conversation with "
    "recent vitals (heart rate, HRV, respiratory rate, distance walked). Treat it as background "
    "data, NOT something the patient typed. Do NOT thank them for sharing it. Use it silently to "
    "inform your questions and possible-causes (e.g. tachycardia + chest pain = different "
    "differential than normal HR + chest pain).\n"
    "• If a vital is abnormal (e.g. HR > 100 at rest, RR > 20, HR < 50), factor it in but DON'T "
    "lecture the patient about the number unless directly relevant.\n"
    "\n"
    "DIAGNOSIS, PRESCRIPTIONS & RED FLAGS:\n"
    "10. Never give a final diagnosis. Provide a short list of 2–5 likely possible causes. Always "
    "include in your summary: \"I am an AI triage assistant, not a doctor. This is a preliminary "
    "assessment.\"\n"
    "11. Red Flags (chest pain, stroke signs, difficulty breathing, severe bleeding, loss of "
    "consciousness, sudden severe headache, signs of sepsis) → IMMEDIATELY tell the user to go to "
    "the nearest ER or call emergency services. Do this even mid-conversation.\n"
    "12. PRESCRIPTIONS / MEDICATIONS — when the patient asks for a prescription, medication, or "
    "what to take, give them a clear, useful answer:\n"
    "    • Give the drug name, the typical adult dose, frequency, and duration. Use what's "
    "actually used in Cameroon (e.g. \"Artemether-lumefantrine 80/480 mg, 4 tablets twice daily "
    "for 3 days\" for uncomplicated malaria, \"Amoxicillin 500 mg three times daily for 7 days\" "
    "for a typical bacterial throat infection).\n"
    "    • Keep it concise — drug, dose, frequency, duration. Don't lecture.\n"
    "    • End the prescription with a single short line: \"Confirm with a doctor or pharmacist "
    "before starting.\" That's it — no extra disclaimers, no asking about pregnancy / kidneys / "
    "allergies, no \"are you sure\" prompts.\n"
    "\n"
    "PROVIDER TYPE — Clinix has two kinds of providers:\n"
    "  • Doctors (generalists & specialists) — VIRTUAL consultations (chat / audio / video). "
    "Distance and budget do NOT matter for them — do NOT ask about location or budget.\n"
    "  • Nurses & midwives — IN-PERSON home care (wound dressing, injections, prenatal home "
    "checks, post-op care, elderly care, vitals at home). The app already knows the patient's "
    "GPS, so do NOT ask their location.\n"
    "If the case obviously needs hands-on home care → recommend a nurse. Otherwise → doctor "
    "(generalist for routine, specialist for area-specific).\n"
    "\n"
    "PROVIDER MATCHING — after the summary, ask ONE short question:\n"
    "  • Doctor case: \"Want me to suggest a doctor on Clinix for this?\"\n"
    "  • Nurse case: \"Want me to recommend a nurse near you for this?\"\n"
    "If the answer is unclear, clarify ONCE. After that, default to YES unless they explicitly "
    "decline. Don't pressure them. Never ask about distance, location, or budget — the app "
    "handles those."
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
            'Output ONE friendly opening line, max 12 words. '
            'No introduction, no role description, no "triage" or "ABCDE" or any clinical jargon, '
            'no advice, no preamble. Just a warm greeting that asks what is bothering them today. '
            'Examples of good output:\n'
            '  - "Hi! What\'s bothering you today?"\n'
            '  - "Hello \u2014 tell me what\'s going on with your health."\n'
            '  - "Hey, what brings you here today?"\n'
            'Output the message only, no quotes, no formatting.'
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


    def draft_medical_record(self, transcript: str) -> dict:
        """Take a doctor↔patient call transcript and return a structured
        medical-record draft as JSON. The doctor reviews + edits the draft
        before submitting, so the model is allowed to be expansive — anything
        wrong gets corrected by a human."""
        self._require_model()
        prompt = (
            'You are a medical scribe. Read the following CONSULTATION TRANSCRIPT '
            '(doctor and patient speaking) and draft a structured medical record. '
            'Reply with ONLY valid JSON (no markdown fences) in this exact shape:\n'
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
            '- title: 4–8 words summarising the visit (e.g. "Acute sinusitis follow-up").\n'
            '- chief_complaint: one sentence in the patient\'s own framing.\n'
            '- symptoms: array of short symptom phrases extracted from the transcript.\n'
            '- symptom_duration: e.g. "3 days", "2 weeks", or empty if not mentioned.\n'
            '- examination_findings: what the doctor observed/asked about. Empty if nothing.\n'
            '- diagnosis: working or confirmed diagnosis. Empty if doctor didn\'t state one.\n'
            '- treatment_plan: what the doctor advised. Lifestyle, follow-up, referrals.\n'
            '- medications_summary: list of meds with dose/frequency/duration on '
            'separate lines (e.g. "Artemether-lumefantrine 80/480 mg, 4 tablets BID, 3 days").\n'
            '- follow_up_date: only if the doctor explicitly scheduled one. Otherwise empty string.\n'
            '- DO NOT invent details. If the transcript doesn\'t cover a field, leave it empty.\n'
            '- Use the transcript\'s primary language for the prose fields (English or French).\n'
            '\nCONSULTATION TRANSCRIPT:\n'
            f'{transcript[:24000]}'
        )

        def _parse(text: str) -> dict:
            text = (text or '').strip()
            if '```' in text:
                if '```json' in text:
                    text = text.split('```json', 1)[1].split('```', 1)[0].strip()
                else:
                    text = text.split('```', 1)[1].split('```', 1)[0].strip()
            data = json.loads(text)
            data.setdefault('title', '')
            data.setdefault('chief_complaint', '')
            data.setdefault('symptoms', [])
            if not isinstance(data['symptoms'], list):
                data['symptoms'] = [str(data['symptoms'])]
            data.setdefault('symptom_duration', '')
            data.setdefault('examination_findings', '')
            data.setdefault('diagnosis', '')
            data.setdefault('treatment_plan', '')
            data.setdefault('medications_summary', '')
            data.setdefault('follow_up_date', '')
            return data

        try:
            response = self.model.generate_content(prompt, safety_settings=SAFETY_SETTINGS)
            return _parse(response.text)
        except MedLMNotConfigured:
            raise
        except Exception as e:
            if self._should_fallback(e) and self._fallback_model():
                try:
                    response = self.model.generate_content(prompt, safety_settings=SAFETY_SETTINGS)
                    return _parse(response.text)
                except Exception as e2:
                    logger.exception('AI medical-record draft failed after fallback')
                    raise MedLMInferenceError(str(e2)) from e2
            logger.exception('AI medical-record draft failed')
            raise MedLMInferenceError(str(e)) from e


medlm_client = MedLMClient()
