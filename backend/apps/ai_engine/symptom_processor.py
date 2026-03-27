import nltk
from nltk.tokenize import word_tokenize
from nltk.corpus import stopwords
import string

# Ensure NLTK resources are downloaded (handled in post-install or celery task usually)
try:
    nltk.download('punkt', quiet=True)
    nltk.download('stopwords', quiet=True)
except:
    pass

# Mock ICD-10 Mapping
ICD10_MOCK = {
    'fever': 'R50',
    'headache': 'R51',
    'chills': 'R68.8',
    'fatigue': 'R53',
    'burning': 'R30',
    'urination': 'R30.0',
    'frequent': 'R35',
    'pain': 'R52',
    'abdominal': 'R10',
    'dizziness': 'R42',
    'vision': 'H53',
    'weakness': 'M62.8',
    'cough': 'R05',
    'shortness': 'R06.0',
    'breath': 'R06.0',
    'chest': 'R07.9',
    'breathing': 'R06.0',
    'consciousness': 'R40.2'
}

def extract_symptoms(text):
    text = str(text).lower()
    try:
        tokens = word_tokenize(text)
        stop_words = set(stopwords.words('english'))
        filtered_tokens = [w for w in tokens if not w in stop_words and w not in string.punctuation]
    except LookupError:
        # Fallback if NLTK data is missing
        filtered_tokens = text.split()
        
    symptoms = []
    codes = []
    for token in filtered_tokens:
        for key in ICD10_MOCK.keys():
            if key in token or token in key:
                symptoms.append(key)
                codes.append(ICD10_MOCK[key])
    
    # Simple multi-word check
    if 'chest pain' in text:
        symptoms.append('chest pain')
        codes.append('R07.9')
    if 'difficulty breathing' in text or 'shortness of breath' in text:
        symptoms.append('difficulty breathing')
        codes.append('R06.0')
    if 'loss of consciousness' in text or 'fainted' in text:
        symptoms.append('loss of consciousness')
        codes.append('R40.2')
        
    return list(set(symptoms)), list(set(codes))

def calculate_triage_score(symptoms, duration_str, severity):
    text_lower = " ".join(symptoms) + " " + str(duration_str).lower()
    
    # Default score based on duration
    score = 1
    duration = 0 # in days mock
    if 'day' in str(duration_str).lower():
        try:
            val = int("".join(filter(str.isdigit, duration_str)))
            duration = val
        except ValueError:
            duration = 4
            
    if duration > 7:
        score = 1
    elif 3 <= duration <= 7:
        score = 2
    elif 1 <= duration <= 3:
        score = 3
    elif duration < 1 or 'hour' in duration_str.lower():
        score = 4
        
    # Overrides based on red flags
    red_flags = ['chest pain', 'breathing', 'consciousness']
    if any(flag in text_lower for flag in red_flags):
        return 5
        
    # Severity override
    if severity >= 8:
        score = max(score, 4)
    elif severity >= 5:
        score = max(score, 2)
        
    return score
