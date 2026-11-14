# LLM Inference Platform

A FastAPI gateway that exposes an HTTP API for an Ollama-hosted language model. The application uses Ollama's OpenAI-compatible API and defaults to the `qwen3:0.6b` model.

## Repository layout

| Path | Responsibility |
| --- | --- |
| `app/` | FastAPI application code. |
| `tests/` | Pytest unit tests. |
| `infrastructure/terraform/network/` | AWS VPC, subnets, security groups, GitHub OIDC, and shared IAM. |
| `infrastructure/terraform/application/` | AWS EKS, ECR, and SSM Parameter Store application infrastructure. |
| `llm-inference-gitops/` | Helm chart, environment values, and Argo CD application definitions. |
| `.github/workflows/application-image.yml` | Tests, builds, and publishes the immutable application image to ECR. |
| `.github/workflows/ci-cd.yml` | Validates Python, Helm, and Terraform without publishing an image. |

Infrastructure provisioning, application image production, and GitOps release promotion are intentionally separate lifecycles. See [`infrastructure/terraform/README.md`](infrastructure/terraform/README.md) for the AWS bootstrap procedure.

## API endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/health/live` | Confirms the FastAPI process is alive. |
| `GET` | `/health/ready` | Confirms FastAPI can connect to Ollama. |
| `POST` | `/chat` | Sends a prompt to the configured model. |
| `GET` | `/docs` | Opens the interactive Swagger UI. |

Example request:

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Explain Kubernetes pods in simple terms"}'
```

## Prerequisites

- Python 3.11 or later; Python 3.12 is used by the container image
- [Poetry](https://python-poetry.org/)
- [Ollama](https://ollama.com/) running natively on macOS
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Kind](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

Install the default model and start Ollama before running the application:

```bash
ollama pull qwen3:0.6b
ollama serve
```

If Ollama is already running as a macOS service, only `ollama pull` is needed.

## Run locally with Poetry

```bash
poetry install
poetry run pytest
poetry run python3 app/main.py
```

Alternatively, use Uvicorn with automatic reload:

```bash
poetry run uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Verify the application:

```bash
curl http://localhost:8000/health/live
curl http://localhost:8000/health/ready
```

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `INFERENCE_BASE_URL` | `http://localhost:11434/v1` | Ollama OpenAI-compatible API URL. |
| `INFERENCE_API_KEY` | `ollama` | API key passed to the OpenAI client. |
| `INFERENCE_MODEL` | `qwen3:0.6b` | Ollama model used for chat requests. |
| `HOST` | `127.0.0.1` | Host used by the direct Python entry point. |
| `PORT` | `8000` | Port used by the direct Python entry point. |

## Run with Docker

The [Dockerfile](Dockerfile) uses `python:3.12-slim`, installs locked production dependencies, runs as a non-root user, and includes a liveness health check.

Build the image:

```bash
docker build -t llm-inference-platform:latest .
```

Run the container:

```bash
docker run -d \
  --name llm-inference-platform \
  --restart unless-stopped \
  -p 8000:8000 \
  -e INFERENCE_BASE_URL=http://host.docker.internal:11434/v1 \
  -e INFERENCE_MODEL=qwen3:0.6b \
  llm-inference-platform:latest
```

Inside a container, `localhost` refers to the container itself. Docker Desktop provides `host.docker.internal`, which routes requests from the container to Ollama running on macOS.

Check the container:

```bash
docker ps --filter name=llm-inference-platform
docker logs -f llm-inference-platform
curl http://localhost:8000/health/live
curl http://localhost:8000/health/ready
```

Stop the standalone container before deploying to Kind because both deployments use host port `8000`:

```bash
docker stop llm-inference-platform
```

Start it again later with:

```bash
docker start llm-inference-platform
```

## Deploy to Kubernetes with Kind

The Kubernetes files are stored in [`k8s/`](k8s/):

- `kind-config.yaml` creates a single-node cluster and maps host port `8000` to NodePort `30080`.
- `configmap.yaml` configures the Ollama URL and model.
- `deployment.yaml` runs FastAPI with resource limits, probes, and a restricted security context.
- `service.yaml` exposes the workload through a NodePort Service.
- `kustomization.yaml` groups the deployable Kubernetes resources.

### 1. Build the image

```bash
docker build -t llm-inference-platform:latest .
```

### 2. Free port 8000

Stop the standalone container if it is running:

```bash
docker stop llm-inference-platform
```

Also stop any local Poetry or Uvicorn server using port `8000`.

### 3. Create the cluster

```bash
kind create cluster \
  --name llm-inference-platform \
  --config k8s/kind-config.yaml \
  --wait 120s
```

This creates the kubectl context `kind-llm-inference-platform`.

### 4. Load the local image into Kind

Kind nodes cannot automatically see images in the macOS Docker image store, so load it explicitly:

```bash
kind load docker-image llm-inference-platform:latest \
  --name llm-inference-platform
```

### 5. Deploy the application and Service

```bash
kubectl apply -k k8s
kubectl rollout status deployment/llm-inference-platform --timeout=120s
```

### 6. Verify the deployment

```bash
kubectl get deployment,pods,service \
  -l app.kubernetes.io/name=llm-inference-platform -o wide

curl http://localhost:8000/health/live
curl http://localhost:8000/health/ready
```

Expected responses:

```json
{"status":"alive"}
```

```json
{"status":"ready"}
```

Open the Swagger UI at [http://localhost:8000/docs](http://localhost:8000/docs).

## How Kubernetes connects to Ollama on macOS

The ConfigMap sets:

```yaml
INFERENCE_BASE_URL: http://host.docker.internal:11434/v1
```

The connection path is:

```text
FastAPI pod
  -> Kind node container
  -> host.docker.internal:11434
  -> Ollama running natively on macOS
```

The readiness probe calls `/health/ready`. That endpoint requests Ollama's model list, so a ready pod confirms that the Kubernetes workload can reach Ollama.

Inspect the active configuration:

```bash
kubectl get configmap llm-inference-platform-config -o yaml
```

## Update the Kubernetes deployment

After changing application code, rebuild and reload the image, then restart the Deployment:

```bash
docker build -t llm-inference-platform:latest .

kind load docker-image llm-inference-platform:latest \
  --name llm-inference-platform

kubectl rollout restart deployment/llm-inference-platform
kubectl rollout status deployment/llm-inference-platform --timeout=120s
```

After changing Kubernetes YAML:

```bash
kubectl apply -k k8s
kubectl rollout status deployment/llm-inference-platform --timeout=120s
```

## Logs and troubleshooting

Follow application logs:

```bash
kubectl logs -f deployment/llm-inference-platform
```

Inspect pod status and events:

```bash
kubectl get pods
kubectl describe pod -l app.kubernetes.io/name=llm-inference-platform
kubectl get events --sort-by=.metadata.creationTimestamp
```

Test Ollama directly from macOS:

```bash
curl http://localhost:11434/v1/models
```

If liveness succeeds but readiness returns `503`, FastAPI is running but cannot reach Ollama. Confirm that Ollama is running, that the model exists, and that the ConfigMap uses `host.docker.internal` rather than `localhost`.

If port `8000` is already allocated, stop the local Uvicorn process or standalone Docker container before creating the Kind cluster.

## Cleanup

Remove only the application resources while keeping the cluster:

```bash
kubectl delete -k k8s
```

Delete the entire Kind cluster:

```bash
kind delete cluster --name llm-inference-platform
```

## Postman collection

Import [`postman/LLM-Inference-Platform.postman_collection.json`](postman/LLM-Inference-Platform.postman_collection.json) into Postman. Its `baseUrl` variable defaults to `http://localhost:8000` and it contains requests for all three API endpoints.

## Project structure

```text
llm-inference-platform/
├── app/
│   ├── __init__.py
│   └── main.py
├── k8s/
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── kind-config.yaml
│   ├── kustomization.yaml
│   └── service.yaml
├── postman/
│   └── LLM-Inference-Platform.postman_collection.json
├── tests/
├── .dockerignore
├── Dockerfile
├── poetry.lock
├── pyproject.toml
└── README.md
```
