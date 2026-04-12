import os
from transformers import pipeline
from .medlm_client import medlm_client

# Load a lightweight model 
try:
    classifier = pipeline("zero-shot-classification", model="valhalla/distilbart-mnli-12-1")
except Exception as e:
    classifier = None

def get_lightweight_prediction(text, candidate_labels):
    """
    Pass symptoms to a lightweight transformer model as a secondary fallback.
    """
    if not classifier or not text:
        return None, 0.0
    try:
        result = classifier(text, candidate_labels)
        top_label = result['labels'][0]
        score = result['scores'][0]
        return top_label, score
    except:
        return None, 0.0

def match_conditions(symptoms_list):
    """
    Fuses MedLM advanced reasoning with lightweight NLP and keyword rules.
    """
    text = " ".join(symptoms_list)
    
    # ─── MedLM Integration ────────────────────────────────
    medlm_data = medlm_client.query_medical_ai(text)
    if medlm_data:
        # If MedLM provides a high-quality response, use it as primary
        return {
            'suggestions': medlm_data.get('condition_suggestions', ['Unknown Condition']),
            'confidence_score': round((medlm_data.get('confidence_scores', [0.0])[0] if medlm_data.get('confidence_scores') else 0.0) * 100, 2),
            'recommended_specialization': medlm_data.get('recommended_specialization', 'General Practitioner'),
            'recommendation_text': medlm_data.get('clinical_advice', 'Consult a professional diagnosis.')
        }

    # ─── Fallback: Base Sympscan mapping data ─────────────────
    sympscan_rules = {
        # ... existing sympscan_rules ...
        'Malaria': {
            'keywords': ['fever', 'chills', 'headache', 'fatigue', 'sweat'],
            'message': 'Possible malaria, seek testing.',
            'specialization': 'General Practitioner'
        },
        'UTI': {
            'keywords': ['burning', 'urination', 'frequent', 'frequence', 'abdominal', 'urine'],
            'message': 'Possible Urinary Tract Infection.',
            'specialization': 'Urologist'
        },
        'Hypertension': {
            'keywords': ['headache', 'dizziness', 'vision', 'chest'],
            'message': 'Possible Hypertension. Monitor blood pressure.',
            'specialization': 'Cardiologist'
        },
        'Typhoid': {
            'keywords': ['fever', 'abdominal', 'pain', 'weakness', 'diarrhea'],
            'message': 'Possible Typhoid fever. Diagnostic tests recommended.',
            'specialization': 'General Practitioner'
        },
        'Respiratory Infection': {
            'keywords': ['cough', 'fever', 'shortness', 'breath', 'breathing', 'throat'],
            'message': 'Possible Respiratory Infection.',
            'specialization': 'Pulmonologist'
        }
    }
    
    candidate_labels = list(sympscan_rules.keys())
    nlp_match, nlp_score = get_lightweight_prediction(text, candidate_labels)
    
    best_match = None
    max_matches = 0
    confidence = 0.0
    
    # Run Sympscan keyword rules
    for condition, data in sympscan_rules.items():
        matches = sum(1 for kw in data['keywords'] if kw in text)
        if matches > max_matches:
            max_matches = matches
            best_match = condition
            confidence = matches / len(data['keywords'])
            
    # Hybrid Fusion Logic
    if nlp_match and nlp_score > 0.4:
        # If NLP model has high confidence, blend it with Sympscan score
        if nlp_match == best_match:
            # high agreement!
            confidence = min(1.0, confidence + (nlp_score * 0.5))
        elif nlp_score > confidence:
            # Model is more confident than the strict keyword match
            best_match = nlp_match
            confidence = nlp_score * 0.8
            max_matches = 2 # minimum threshold validation
            
    if best_match and max_matches >= 1:
        return {
            'suggestions': [best_match],
            'confidence_score': round(confidence * 100, 2),
            'recommended_specialization': sympscan_rules[best_match]['specialization'],
            'recommendation_text': sympscan_rules[best_match]['message']
        }
        
    return {
        'suggestions': ['Unknown Condition'],
        'confidence_score': 0.0,
        'recommended_specialization': 'General Practitioner',
        'recommendation_text': 'Symptoms vary. Please consult a doctor for a professional diagnosis.'
    }

