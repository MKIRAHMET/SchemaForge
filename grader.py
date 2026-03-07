import json
from pathlib import Path

results_path = Path("/workdir/validation_results.json")
data = json.loads(results_path.read_text())

validation_results = data.get('validation_results', [])
summary = data.get('summary', {})


if not isinstance(validation_results, list):
    raise ValueError("validation_results must be a list")

if not isinstance(summary, dict):
    raise ValueError("summary must be a dictionary")

total_docs = summary.get('total_documents', 0)
valid_docs = summary.get('valid_documents', 0)

score = 0.0

if total_docs > 0:
    score = valid_docs / total_docs

print("Total Documents:", total_docs)
print("Valid Documents:", valid_docs)
print("Score:", score)
