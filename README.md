# SchemaForge

A Dockerized JSON Schema validator and grading pipeline for AI agent evaluation.

SchemaForge validates JSON documents against predefined schemas, generates structured error reports, and verifies output correctness through a ground-truth grader.

## Why SchemaForge

AI-generated output can look correct while still being wrong.

SchemaForge is designed to solve that problem by combining:

- deterministic JSON validation
- structured error reporting
- Docker-based reproducibility
- an independent grader that computes ground truth
- a clean task format for evaluating agent behavior

## Features

- Validates documents against schema definitions
- Supports common JSON Schema-style rules
- Produces machine-readable validation results
- Runs inside Docker for reproducible execution
- Includes a grader that compares actual output with expected ground truth

## Supported validation rules

### Types

- `string`
- `number`
- `integer`
- `boolean`
- `null`
- `array`
- `object`

### String constraints

- `minLength`
- `maxLength`
- `pattern`
- `format: email`
- `format: date`
- `format: uuid`
- `format: uri`

### Number constraints

- `minimum`
- `maximum`
- `exclusiveMinimum`
- `exclusiveMaximum`
- `multipleOf`

### Array constraints

- `minItems`
- `maxItems`
- `uniqueItems`
- `items`

### Object constraints

- `required`
- `properties`
- `additionalProperties`

### Enum

- `enum`

## Project structure

    schema_validator/
    ├── data/
    │   └── validation_request.json
    ├── tests/
    │   └── validation_request.json
    ├── Dockerfile
    ├── task.yaml
    ├── grader.py
    └── solution.sh

## How it works

1. A Docker image is built from the project `Dockerfile`
2. Input data is loaded from `/workdir/data/validation_request.json`
3. The validator runs inside the container
4. Results are written to `/workdir/validation_results.json`
5. The grader computes expected ground truth from the hidden test data
6. The grader compares expected vs actual output and returns a score

## Output format

SchemaForge produces output like this:

    {
      "validation_results": [
        {
          "document_id": "doc_001",
          "schema_id": "schema_user",
          "valid": true,
          "errors": []
        }
      ],
      "summary": {
        "total_documents": 10,
        "valid_documents": 3,
        "invalid_documents": 7,
        "total_errors": 19,
        "errors_by_constraint": {
          "type": 2,
          "format": 3
        }
      }
    }

Each validation error uses this structure:

    {
      "path": "$.email",
      "message": "Invalid email format",
      "constraint": "format",
      "expected": "email",
      "actual": "not-an-email"
    }

## Requirements

- Python 3.8+
- Docker Desktop
- Optional: PyYAML

## Setup

Make the CLI executable:

    chmod +x apex-arena

If you are using WSL on Windows, make sure Docker Desktop WSL integration is enabled.

## Run locally

### List tasks

    ./apex-arena list-tasks

### Validate task structure

    ./apex-arena validate-task schema_validator

### Test the solution

    ./apex-arena test-solution schema_validator --force

### Debug inside the container

    ./apex-arena test-solution schema_validator --force -k
    docker exec -it <container_name> bash

## Example result

Expected summary for the included dataset:

    {
      "total_documents": 10,
      "valid_documents": 3,
      "invalid_documents": 7,
      "total_errors": 19
    }

## Design notes

SchemaForge is intentionally lightweight:

- Python standard library only
- no external schema validation packages
- explicit validation logic
- deterministic output
- transparent grading behavior

This makes it easier to inspect, debug, and extend.

## Key implementation details

### `solution.sh`

Runs the reference validator inside the container and writes:

    /workdir/validation_results.json

### `grader.py`

Loads the hidden input from:

    /tests/validation_request.json

Computes the expected results independently, then compares them against the agent output.

### `task.yaml`

Defines the task prompt, metadata, and evaluation environment.

## Why the grader matters

A weak grader only checks that output looks correct.

SchemaForge uses a stronger approach:

- load hidden input
- recompute expected results
- compare expected and actual outputs exactly
- return a binary score

This makes evaluation more trustworthy for AI systems.

## Roadmap

Possible future improvements:

- broader JSON Schema support
- cleaner missing-property paths
- richer formatter support
- friendlier CLI reporting
- benchmark suites for multiple agents
- exportable validation reports
