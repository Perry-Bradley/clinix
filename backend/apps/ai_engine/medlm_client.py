import os
import json
import logging
import vertexai
from vertexai.generative_models import GenerativeModel, Content, Part

logger = logging.getLogger(__name__)


class MedLMNotConfigured(Exception):
    """GCP / Vertex AI is not configured (env vars or credentials)."""


class MedLMInferenceError(Exception):
    """Model call failed or returned unusable output."""


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

        self.project_id = os.getenv('GCP_PROJECT_ID') or os.getenv('GOOGLE_CLOUD_PROJECT')
        self.location = os.getenv('GCP_LOCATION', 'us-central1')
        self.model_id = os.getenv('MEDLM_MODEL_ID', 'medlm-medium')
        self._model_ready = False
        self.model = None

        if self.project_id:
            try:
                vertexai.init(project=self.project_id, location=self.location)
                self.model = GenerativeModel(self.model_id)
                self._model_ready = True
                logger.info('MedLMClient ready: model=%s project=%s', self.model_id, self.project_id)
            except Exception:
                logger.exception('MedLMClient init failed')
                self._model_ready = False
        else:
            logger.warning('GCP_PROJECT_ID / GOOGLE_CLOUD_PROJECT not set.')

    def _require_model(self):
        if not self._model_ready or self.model is None:
            raise MedLMNotConfigured(
                'MedLM is not available. Set GCP_PROJECT_ID or GOOGLE_CLOUD_PROJECT, GCP_LOCATION, '
                'MEDLM_MODEL_ID, and authenticate with Application Default Credentials '
                '(e.g. gcloud auth application-default login) or a service account. '
                'Then install dependencies: pip install -r requirements.txt (includes daphne, google-cloud-aiplatform).'
            )

    def _history_to_contents(self, history):
        contents = []
        for turn in history:
            role = turn.get('role', 'user')
            parts = turn.get('parts') or ['']
            text = parts[0] if isinstance(parts, (list, tuple)) else str(parts)
            grole = 'user' if role == 'user' else 'model'
            contents.append(Content(role=grole, parts=[Part.from_text(text)]))
        return contents

    def get_opening_message(self) -> str:
        self._require_model()
        prompt = (
            'You are Clinix AI, a medical triage assistant for patients in Cameroon using the Clinix app. '
            'Write exactly one short opening message (2–3 sentences). Introduce yourself, be warm and professional, '
            'and ask what symptom or health concern they want help with today. '
            'Do not give medical advice, diagnosis, or facts in this message.'
        )
        try:
            response = self.model.generate_content([prompt])
            text = (response.text or '').strip()
            if not text:
                raise MedLMInferenceError('Model returned an empty opening message.')
            return text
        except MedLMNotConfigured:
            raise
        except Exception as e:
            logger.exception('MedLM opening message failed')
            raise MedLMInferenceError(str(e)) from e

    def get_chat_response(self, history, message: str) -> str:
        self._require_model()

        system_instruction = (
            'You are Clinix AI, a medical triage assistant. Be concise, empathetic, and professional. '
            'Ask one focused follow-up at a time. Never claim a definitive diagnosis; remind the user you are an AI. '
            'If symptoms sound urgent (chest pain, severe bleeding, trouble breathing, confusion, stroke signs), '
            'tell them to seek emergency care immediately.'
        )

        try:
            contents = self._history_to_contents(history)
            chat = self.model.start_chat(history=contents)
            prompt = f'{system_instruction}\n\nPatient says:\n{message}' if not history else message
            response = chat.send_message(prompt)
            text = (response.text or '').strip()
            if not text:
                raise MedLMInferenceError('Model returned an empty reply.')
            return text
        except MedLMNotConfigured:
            raise
        except MedLMInferenceError:
            raise
        except Exception as e:
            logger.exception('MedLM chat failed')
            raise MedLMInferenceError(str(e)) from e

    def get_structured_assessment(self, history) -> dict:
        self._require_model()

        prompt = (
            'Based on the conversation, reply with ONLY valid JSON (no markdown fences) in this exact shape:\n'
            '{"potential_conditions": ["string"], "triage_priority": "Low|Medium|High", '
            '"recommended_specialization": "string", "summary": "string"}\n'
        )

        try:
            contents = self._history_to_contents(history)
            chat = self.model.start_chat(history=contents)
            response = chat.send_message(prompt)
            text = (response.text or '').strip()
            if '```' in text:
                if '```json' in text:
                    text = text.split('```json', 1)[1].split('```', 1)[0].strip()
                else:
                    text = text.split('```', 1)[1].split('```', 1)[0].strip()
            data = json.loads(text)
            required = ('triage_priority', 'recommended_specialization', 'summary')
            for k in required:
                if k not in data:
                    raise ValueError(f'Missing key: {k}')
            data.setdefault('potential_conditions', [])
            return data
        except MedLMNotConfigured:
            raise
        except Exception as e:
            logger.exception('Structured assessment failed')
            raise MedLMInferenceError(str(e)) from e


medlm_client = MedLMClient()
