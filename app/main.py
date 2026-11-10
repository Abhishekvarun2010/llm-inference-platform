from fastapi import FastAPI

app = FastAPI(
    title="LLM Inference Platform",
    description="API platform for LLM inference services",
    version="0.1.0",
)


@app.get("/")
async def root():
    return {"message": "Welcome to LLM Inference Platform"}


@app.get("/health")
async def health_check():
    return {"status": "healthy"}
