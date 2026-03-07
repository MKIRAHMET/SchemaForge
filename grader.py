import json
from pathlib import Path
from apex_arena._types import GradingResult 

def grade(_: str) -> GradingResult:
    results_path = Path("/workdir/validation_results.json")
    if not results_path.exists():
        return GradingResult(
            score = 0.0,
            feedback = 'File not found'
        )
    try:
        data = json.loads(results_path.read_text())
    except Exception:
        return GradingResult(
            score = 0.0,
            feedback = 'Invalid JSON format'
        ) 
    
    validation_results = data.get('validation_results', [])
    summary = data.get('summary', {})


    if not isinstance(validation_results, list):
        raise ValueError("validation_results must be a list")

    if not isinstance(summary, dict):
        raise ValueError("summary must be a dictionary")

    total_docs = summary.get('total_documents', 0)
    valid_docs = summary.get('valid_documents', 0)

    if not isinstance(total_docs, int) or not isinstance(valid_docs, int):
        raise ValueError("total_documents and valid_documents must be integers")

    if total_docs != len(validation_results):
        return GradingResult(
            score = 0.0,
            feedback = 'total_documents does not match the number of validation results'
        )

    score = 0.0

    if total_docs > 0:
        score = valid_docs / total_docs


    for result in validation_results:
        if 'document_id' not in result:
            raise ValueError("Missing document_id in result")
        if 'valid' not in result:
            raise ValueError("Missing valid in result")
        if 'errors' not in result:
            raise ValueError("Missing errors in result")


    return GradingResult(
        score=score,
        subscores={'validation': score},
        weights={'validation': 1.0},
        feedback=f"Validated {valid_docs} out of {total_docs} documents"
    )


