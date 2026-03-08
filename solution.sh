#!/usr/bin/env bash
set -euo pipefail

python3 << 'PY'
import json
from pathlib import Path
import re
from datetime import datetime
import uuid


input_path = Path("/workdir/data/validation_request.json")
data = json.loads(input_path.read_text())

schemas = data['schemas']
documents = data['documents']

validation_results = []

schema_dict = {schema['schema_id']: schema['schema'] for schema in schemas}

def check_type(value, expected_type):
    if expected_type == "string":
        return isinstance(value, str)
    elif expected_type == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    elif expected_type == "number":
        return isinstance(value, (int, float))
    elif expected_type == "boolean":
        return isinstance(value, bool)
    elif expected_type == "null":
        return value is None
    elif expected_type == "array":
        return isinstance(value, list)
    elif expected_type == "object":
        return isinstance(value, dict)
    else:
        return False

def validate_string(field_path, value, rules):
    errors = []
    if "minLength" in rules and len(value) < rules["minLength"]:
        errors.append({
            'path': field_path,
            'message': f"String too short, minimum is {rules['minLength']}",
            'constraint': 'minLength',
            'expected': rules['minLength'],
            'actual': len(value)
        })
    if "maxLength" in rules and len(value) > rules["maxLength"]:
        errors.append({
            'path': field_path,
            'message': f"String too long, maximum is {rules['maxLength']}",
            'constraint': 'maxLength',
            'expected': rules['maxLength'],
            'actual': len(value)
        })
    if "pattern" in rules:
        if not re.match(rules["pattern"], value):
            errors.append({
                'path': field_path,
                'message': f"String does not match pattern {rules['pattern']}",
                'constraint': 'pattern',
                'expected': rules['pattern'],
                'actual': value
            })
    if "format" in rules:
        fmt = rules["format"]
        if fmt == 'email' and not re.match(r"^[^@]+@[^@]+\.[^@]+$", value):
            errors.append({
                'path': field_path,
                'message': "Invalid email format",
                'constraint': 'format',
                'expected': 'email',
                'actual': value
            })
        elif fmt == 'date':
            try:
                datetime.strptime(value, "%Y-%m-%d")
            except ValueError:
                errors.append({
                    'path': field_path,
                    'message': "Invalid date format",
                    'constraint': 'format',
                    'expected': 'date',
                    'actual': value
                }) 
        elif fmt == 'uuid':
            try:
                uuid.UUID(value)
            except ValueError:
                errors.append({
                    'path': field_path,
                    'message': "Invalid UUID",
                    'constraint': 'format',
                    'expected': 'uuid',
                    'actual': value
                })  
        elif fmt == 'uri':
            if not (value.startswith("http://") or value.startswith("https://")):
                errors.append({
                    'path': field_path,
                    'message': "Invalid URI format",
                    'constraint': 'format',
                    'expected': 'uri',
                    'actual': value
                })
    return errors

def validate_number(field_path, value, rules):
    errors = []
    if 'minimum' in rules:
        min_val = rules['minimum']
        if rules.get("exclusiveMinimum", False):
            if value <= min_val:
                errors.append({
                    'path' : field_path,
                    'message': 'Value <= exclusive minimum',
                    'constraint': 'exclusiveMinimum',
                    'expected': f'>{min_val}',
                    'actual': value
                })
        else:
            if value < min_val:
                errors.append({
                    'path' : field_path,
                    'message': 'Value < minimum',
                    'constraint': 'minimum',
                    'expected': min_val,
                    'actual': value
                })
    if 'maximum' in rules:
        max_val = rules['maximum']
        if rules.get("exclusiveMaximum", False):
            if value >= max_val:
                errors.append({
                    'path' : field_path,
                    'message': 'Value >= exclusive maximum',
                    'constraint': 'exclusiveMaximum',
                    'expected': f'<{max_val}',
                    'actual': value
                })
        else:
            if value > max_val:
                errors.append({
                    'path' : field_path,
                    'message': 'Value > maximum',
                    'constraint': 'maximum',
                    'expected': max_val,
                    'actual': value
                })
    if 'multipleOf' in rules:
        divisor = rules['multipleOf']
        if value / divisor != int(value / divisor):
            errors.append({
                'path' : field_path,
                'message' : 'Value not a multiple',
                'constraint' : 'multipleOf',
                'expected' : divisor,
                'actual' : value
                })
    return errors


def validate_array(field_path, value, rules):
    errors = []
    if 'minItems' in rules and len(value) < rules['minItems']:
        errors.append({
            'path': field_path,
            'message': f"Array too short (min {rules['minItems']})",
            'constraint': 'minItems',
            'expected': rules['minItems'],
            'actual': len(value)
        })
    if 'maxItems' in rules and len(value) > rules['maxItems']:
        errors.append({
            'path': field_path,
            'message': f"Array too long (max {rules['maxItems']})",
            'constraint': 'maxItems',
            'expected': rules['maxItems'],
            'actual': len(value)
        })
    if rules.get('uniqueItems', False):
        if len(value) != len(set(map(str, value))):
            errors.append({
                'path': field_path,
                'message': "Array items not unique",
                'constraint': 'uniqueItems',
                'expected': 'all unique',
                'actual': value
            })
    if 'items' in rules:
        item_schema = rules ['items']
        for idx, item in enumerate(value):
            item_path = f"{field_path}[{idx}]"
            errors += validate_field(item_path, item, item_schema)
    return errors

def validate_object(field_path, value, rules):
    errors = []

    for req in rules.get('required', []):
        if req not in value:
            errors.append({
                'path': field_path,
                'message': "Missing required property",
                'constraint': 'required',
                'expected': 'present',
                'actual': 'missing'
            })    

    props = rules.get('properties', {})
    for key, prop_schema in props.items():
        if key in value:
            errors += validate_field(f"{field_path}.{key}", value[key], prop_schema)
    
    if rules.get('additionalProperties', True) is False:
        allowed_keys = set(props.keys())
        for key in value:
            if key not in allowed_keys:
                errors.append({
                    'path': field_path,
                    'message': f"Additional property '{key}' not allowed",
                    'constraint': 'additionalProperties',
                    'expected': f"only {', '.join(allowed_keys)}",
                    'actual': key
                })
    return errors

def validate_enum(field_path, value, rules):
    errors = []
    if "enum" in rules and value not in rules['enum']:
        errors.append({
            'path': field_path,
            'message': f"Value not in enum {rules['enum']}",
            'constraint': 'enum',
            'expected': rules['enum'],
            'actual': value
        })
    return errors

def validate_field(field_path, value, rules):
    errors = []
    expected_type = rules.get('type')
    if expected_type and not check_type(value, expected_type):
        errors.append({
            'path': field_path,
            'message': f"Type mismatch, expected {expected_type}",
            'constraint': 'type',
            'expected': expected_type,
            'actual': type(value).__name__
        })
        return errors
    
    errors += validate_enum(field_path, value, rules)

    if expected_type == 'string':
        errors += validate_string(field_path, value, rules)
    elif expected_type in ('integer', 'number'):
        errors += validate_number(field_path, value, rules)
    elif expected_type == 'array':
        errors += validate_array(field_path, value, rules)
    elif expected_type == 'object':
        errors += validate_object(field_path, value, rules)

    return errors

def validate_document(doc_data, schema):
    return validate_field('$', doc_data, schema)

for doc in documents:
    doc_id = doc['document_id']
    schema_id = doc['schema_id']
    doc_data = doc['data']
    schema = schema_dict.get(schema_id)

    if not schema:
        validation_results.append({
            'document_id': doc_id,
            'schema_id': schema_id,
            'valid': False,
            'errors': [{
                'path': '$',
                'message': 'Schema not found',
                'constraint': 'schema',
                'expected': 'existing schema',
                'actual': schema_id
            }]
        })
        continue

    errors = validate_document(doc_data, schema)
    validation_results.append({
            'document_id': doc_id,
            'schema_id': schema_id,
            'valid': len(errors) == 0,
            'errors': errors
        })
errors_by_constraint = {}
for result in validation_results:
    for error in result['errors']:
        constraint = error['constraint']
        errors_by_constraint[constraint] = errors_by_constraint.get(constraint, 0) + 1

summary = {
    'total_documents': len(documents),
    'valid_documents': sum(1 for r in validation_results if r['valid']),
    'invalid_documents': sum(1 for r in validation_results if not r['valid']),
    'total_errors': sum(len(r['errors']) for r in validation_results),
    'errors_by_constraint': errors_by_constraint
}

output = Path("/workdir/validation_results.json")
output.write_text(json.dumps({
    'validation_results': validation_results,
    'summary': summary
}, indent=2))
PY