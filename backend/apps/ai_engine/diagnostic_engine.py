def match_conditions(symptoms_list):
    text = " ".join(symptoms_list).lower()
    
    rules = {
        'Malaria': {
            'keywords': ['fever', 'chills', 'headache', 'fatigue'],
            'message': 'Possible malaria, seek testing.',
            'specialization': 'General Practitioner'
        },
        'UTI': {
            'keywords': ['burning', 'urination', 'frequent', 'frequence', 'abdominal', 'pain'],
            'message': 'Possible Urinary Tract Infection.',
            'specialization': 'Urologist'
        },
        'Hypertension': {
            'keywords': ['headache', 'dizziness', 'vision'],
            'message': 'Possible Hypertension. Monitor blood pressure.',
            'specialization': 'Cardiologist'
        },
        'Typhoid': {
            'keywords': ['fever', 'abdominal', 'pain', 'weakness'],
            'message': 'Possible Typhoid fever. Diagnostic tests recommended.',
            'specialization': 'General Practitioner'
        },
        'Respiratory Infection': {
            'keywords': ['cough', 'fever', 'shortness', 'breath', 'breathing'],
            'message': 'Possible Respiratory Infection.',
            'specialization': 'Pulmonologist'
        }
    }
    
    best_match = None
    max_matches = 0
    confidence = 0.0
    
    for condition, data in rules.items():
        matches = sum(1 for kw in data['keywords'] if kw in text)
        if matches > max_matches:
            max_matches = matches
            best_match = condition
            confidence = matches / len(data['keywords'])
            
    if best_match and max_matches >= 2:
        return {
            'suggestions': [best_match],
            'confidence_score': round(confidence * 100, 2),
            'recommended_specialization': rules[best_match]['specialization'],
            'recommendation_text': rules[best_match]['message']
        }
        
    return {
        'suggestions': ['Unknown Condition'],
        'confidence_score': 0.0,
        'recommended_specialization': 'General Practitioner',
        'recommendation_text': 'Symptoms vary. Please consult a doctor for a professional diagnosis.'
    }
