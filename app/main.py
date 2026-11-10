
import os
import time
import logging

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from openai import AsyncOpenAI, APIConnectionError, APITimeoutError, APIStatusError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("inference-gateway")

app = FastAPI(
    title="LLM Inference Gateway",
    version="1.0.0"
)

client = AsyncOpenAI(
    base_url=os.getenv(
        "INFERENCE_BASE_URL",
        "http://localhost:11434/v1"
    ),
    api_key=os.getenv("INFERENCE_API_KEY", "ollama"),
    timeout=120.0,
    max_retries=0,
)

MODEL = os.getenv("INFERENCE_MODEL", "qwen3:0.6b")


class ChatRequest(BaseModel):
    prompt: str = Field(min_length=1, max_length=10000)


@app.get("/health/live")
async def liveness():
    return {"status": "alive"}


@app.get("/health/ready")
async def readiness():
    try:
        await client.models.list()
        return {"status": "ready"}
    except Exception:
        raise HTTPException(
            status_code=503,
            detail="Inference backend unavailable"
        )


@app.post("/chat")
async def chat(request: ChatRequest):
    start = time.perf_counter()

    try:
        response = await client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "user", "content": request.prompt}
            ],
            max_tokens=1024,
        )

        latency = time.perf_counter() - start

        logger.info(
            "Inference completed model=%s latency=%.3fs",
            MODEL,
            latency
        )

        return {
            "model": MODEL,
            "response": response.choices[0].message.content,
            "latency_seconds": round(latency, 3)
        }

    except (APIConnectionError, APITimeoutError) as exc:
        logger.error("Inference backend unavailable: %s", exc)
        raise HTTPException(
            status_code=503,
            detail="Inference backend unavailable"
        )

    except APIStatusError as exc:
        logger.error("Inference backend error: %s", exc)
        raise HTTPException(
            status_code=502,
            detail="Inference backend returned an error"
        )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host=os.getenv("HOST", "127.0.0.1"),
        port=int(os.getenv("PORT", "8000")),
    )
