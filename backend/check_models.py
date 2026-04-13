import google.generativeai as genai
import os
import sys

from dotenv import load_dotenv
load_dotenv()

key = os.environ.get("GEMINI_API_KEY")
if not key:
    print("NO KEY")
    sys.exit(1)

genai.configure(api_key=key)
try:
    models = genai.list_models()
    for m in models:
        print(m.name, m.supported_generation_methods)
except Exception as e:
    print("ERROR:", e)
