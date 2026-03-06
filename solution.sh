#!/usr/bin/env bash
set -euo pipefail

python3 << 'PY'
import json
from pathlib import Path

input_path = Path("/workdir/data/validation_request.json")
data = json.loads(input_path.read_text())

schemas = data [ 'schemas']
documents = data [ 'documents']

validation_results = []

schema_dict = {schema['id']: schema for s in schemas}

def validate(doc_data, schema):
    errors = []

    return errors

    for doc in documents:
        doc_id = doc['document_id']
        schema_id = doc['schema_id']
        doc_data = doc.get('data', {})

        schema = schema_dict[schema_id]

        errors = validate(doc_data, schema)
        validation_results.append({
            'document_id': doc_id,
            'schema_id': schema_id,
            'valid': len(errors) == 0,
            'errors': errors
        })

summary = {
    'total_documents': len(documents),
    'valid_documents': sum(1 for r in validation_results if r['valid']),
    'invalid_documents': sum(1 for r in validation_results if not r['valid'])
    'total_errors': sum(len(r['errors']) for r in validation_results)
    'errors_by_constraint': {}
}

output = Path("/workdir/data/validation_results.json")
json.dump({
    'validation_results': validation_results,
    'summary': summary
}, output.open('w'), indent=2)
