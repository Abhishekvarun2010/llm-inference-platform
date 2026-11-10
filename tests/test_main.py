from types import SimpleNamespace
from unittest.mock import AsyncMock

import httpx
import pytest
from fastapi.testclient import TestClient
from openai import APIConnectionError, APIStatusError, APITimeoutError

from app import main


@pytest.fixture
def api_client():
    return TestClient(main.app)


def test_liveness(api_client):
    response = api_client.get("/health/live")

    assert response.status_code == 200
    assert response.json() == {"status": "alive"}


def test_readiness_when_backend_is_available(api_client, monkeypatch):
    list_models = AsyncMock(return_value=SimpleNamespace(data=[]))
    monkeypatch.setattr(main.client.models, "list", list_models)

    response = api_client.get("/health/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}
    list_models.assert_awaited_once_with()


def test_readiness_when_backend_is_unavailable(api_client, monkeypatch):
    list_models = AsyncMock(side_effect=RuntimeError("backend unavailable"))
    monkeypatch.setattr(main.client.models, "list", list_models)

    response = api_client.get("/health/ready")

    assert response.status_code == 503
    assert response.json() == {"detail": "Inference backend unavailable"}


def test_chat_returns_model_response(api_client, monkeypatch):
    completion = SimpleNamespace(
        choices=[
            SimpleNamespace(
                message=SimpleNamespace(content="Red and orange make red-orange.")
            )
        ]
    )
    create_completion = AsyncMock(return_value=completion)
    monkeypatch.setattr(main.client.chat.completions, "create", create_completion)

    response = api_client.post("/chat", json={"prompt": "What is red + orange?"})

    assert response.status_code == 200
    response_body = response.json()
    assert response_body["model"] == main.MODEL
    assert response_body["response"] == "Red and orange make red-orange."
    assert isinstance(response_body["latency_seconds"], float)
    assert response_body["latency_seconds"] >= 0
    create_completion.assert_awaited_once_with(
        model=main.MODEL,
        messages=[{"role": "user", "content": "What is red + orange?"}],
        max_tokens=1024,
    )


@pytest.mark.parametrize(
    "backend_error",
    [
        APIConnectionError(
            request=httpx.Request("POST", "http://ollama.test/v1/chat/completions")
        ),
        APITimeoutError(
            request=httpx.Request("POST", "http://ollama.test/v1/chat/completions")
        ),
    ],
)
def test_chat_returns_503_for_connection_failures(
    api_client, monkeypatch, backend_error
):
    create_completion = AsyncMock(side_effect=backend_error)
    monkeypatch.setattr(main.client.chat.completions, "create", create_completion)

    response = api_client.post("/chat", json={"prompt": "Hello"})

    assert response.status_code == 503
    assert response.json() == {"detail": "Inference backend unavailable"}


def test_chat_returns_502_for_backend_status_error(api_client, monkeypatch):
    request = httpx.Request("POST", "http://ollama.test/v1/chat/completions")
    backend_response = httpx.Response(500, request=request)
    backend_error = APIStatusError(
        "backend failed",
        response=backend_response,
        body={"error": "failure"},
    )
    create_completion = AsyncMock(side_effect=backend_error)
    monkeypatch.setattr(main.client.chat.completions, "create", create_completion)

    response = api_client.post("/chat", json={"prompt": "Hello"})

    assert response.status_code == 502
    assert response.json() == {"detail": "Inference backend returned an error"}


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"prompt": ""},
        {"prompt": "x" * 10001},
    ],
)
def test_chat_rejects_invalid_prompts(api_client, payload):
    response = api_client.post("/chat", json=payload)

    assert response.status_code == 422
