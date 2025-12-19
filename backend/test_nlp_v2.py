import json  
from nlp_service import nlp_service

sample_job_text = """
We are looking for a Senior Developer.
Python and Django are required for this role.
Experience with Docker is a must.
Knowledge of React is a big plus.
Familiarity with AWS would be an advantage.
You will also use Git for version control.
"""

print("--- NLP 2.0 Analiz Sonucu ---")
result = nlp_service.analyze_job_description(sample_job_text)
print(json.dumps(result, indent=2))