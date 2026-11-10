# LLM Inference Platform

A platform for LLM (Large Language Model) inference.

## Requirements

- Python >= 3.11
- [Poetry](https://python-poetry.org/) (or pip)

## Setup

### Using Poetry

```bash
# Install dependencies
poetry install

# Run tests
poetry run pytest

# Run dev server
poetry run uvicorn app.main:app --reload
```

### Using pip

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Project Structure

```
llm-inference-platform/
├── app/
│   ├── __init__.py
│   └── main.py
├── tests/
│   ├── __init__.py
│   └── test_main.py
├── .venv/
├── pyproject.toml
├── requirements.txt
└── README.md
```
