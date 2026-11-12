# Inference Gateway GitOps

This directory contains the Helm chart, environment values, and Argo CD Application used to deploy the FastAPI inference gateway.

## Layout

```text
llm-inference-gitops/
├── applications/
│   └── gateway-local.yaml
├── charts/
│   └── inference-gateway/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── configmap.yaml
│           ├── rollout.yaml
│           └── service.yaml
└── environments/
    ├── aws-dev/values.yaml
    └── local/values.yaml
```

## Local architecture

Argo CD reads the Helm chart from the `main` branch of this repository and deploys it into the `inference` namespace.

```text
GitHub repository
  -> Argo CD Application
  -> Helm chart + local values
  -> inference namespace
  -> Argo Rollout (blue-green)
  -> active NodePort Service 30080 / preview ClusterIP Service
  -> active or preview FastAPI pod port 8000
```

The Kind cluster maps macOS port `8000` to node port `30080`. The pod reaches native macOS Ollama through `http://host.docker.internal:11434/v1`.

## Blue-green deployment

The chart renders an Argo Rollouts `Rollout` instead of a Kubernetes `Deployment`:

- `llm-inference-platform` is the active Service. Locally it remains NodePort `30080`, so the promoted version is available at `http://localhost:8000`.
- `llm-inference-platform-preview` is a ClusterIP Service that selects the candidate ReplicaSet.
- Automatic promotion is disabled. A new candidate must become Ready and be validated before it is promoted.
- The previous ReplicaSet is scaled down 30 seconds after promotion, and two revisions are retained for rollback history.

Install the Argo Rollouts controller before synchronizing this chart:

```bash
kubectl create namespace argo-rollouts
kubectl apply --server-side --force-conflicts -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl rollout status deployment/argo-rollouts -n argo-rollouts --timeout=240s
```

During a rollout, expose and validate the preview Service:

```bash
kubectl port-forward -n inference service/llm-inference-platform-preview 8081:8000
curl http://localhost:8081/health/live
curl http://localhost:8081/health/ready
```

After validation, promote the candidate. This requires the Argo Rollouts kubectl plugin:

```bash
kubectl argo rollouts get rollout llm-inference-platform -n inference --watch
kubectl argo rollouts promote llm-inference-platform -n inference
```

The Rollout changes only when its pod template changes. Pushing new bytes to the existing `latest` tag does not change the Git manifest and therefore does not start blue-green deployment. Use a unique image tag or, preferably, an immutable digest in Git for every release.

## Validate the chart

Run from `llm-inference-gitops/`:

```bash
helm lint charts/inference-gateway \
  -f environments/local/values.yaml

helm template inference-gateway \
  charts/inference-gateway \
  --namespace inference \
  -f environments/local/values.yaml
```

The local values always pull the `latest` GHCR image. Because the current GHCR package is private, create `ghcr-pull-secret` in the `inference` namespace before synchronizing the Application. Do not commit registry credentials to Git. AWS-dev remains digest-pinned for immutable deployments.

## Immutable container images

The chart supports both tag-based and digest-based image references:

```yaml
image:
  repository: ghcr.io/abhishekvarun2010/llm-inference-platform
  tag: latest
  digest: ""
```

When `image.digest` is empty, Helm renders `repository:tag`. When it is set, the digest takes precedence and Helm renders the immutable `repository@sha256:...` reference.

Validate digest rendering with:

```bash
helm template inference-gateway charts/inference-gateway \
  -f environments/aws-dev/values.yaml \
  | grep 'image:'
```

## CI/CD pipeline

The workflow at `.github/workflows/ci-cd.yml`:

1. Installs Poetry dependencies and runs pytest.
2. Lints the Helm chart.
3. Tests tag- and digest-based Helm rendering.
4. Builds and pushes commit-SHA and `latest` image tags to GHCR on `main`.
5. Captures the registry digest and writes it to `environments/aws-dev/values.yaml`.
6. Commits the immutable GitOps digest back to `main`.

The workflow uses `GITHUB_TOKEN` with `packages: write` and `contents: write`; no registry password secret is required.

## Install Argo CD

```bash
kubectl create namespace argocd

kubectl apply --server-side --force-conflicts \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=Ready pod \
  --all -n argocd --timeout=240s
```

## Deploy through Argo CD

Commit and push this directory before syncing because Argo CD reads from GitHub, not the local filesystem.

Remove the old manually managed resources:

```bash
kubectl delete deployment llm-inference-platform -n default
kubectl delete service llm-inference-platform -n default
kubectl delete configmap llm-inference-platform-config -n default
```

Create or update the Argo CD Application:

```bash
kubectl apply -f llm-inference-gitops/applications/gateway-local.yaml
```

Automated sync, pruning, and self-healing are enabled. Watch deployment progress:

```bash
kubectl get application inference-gateway-local -n argocd -w
kubectl get pods -n inference -w
```

Verify the application:

```bash
kubectl get application inference-gateway-local -n argocd
kubectl get rollout,replicaset,pod,service -n inference
curl http://localhost:8000/health/live
curl http://localhost:8000/health/ready
```

## Update the application

For application code changes, build and push a uniquely tagged or digest-addressed image, then update the environment values in Git. For chart or environment changes, commit and push the GitOps files. Argo CD detects the new revision and synchronizes it automatically:

```bash
git add llm-inference-gitops
git commit -m "Update inference gateway GitOps configuration"
git push origin main
```

## Troubleshooting

```bash
kubectl describe application inference-gateway-local -n argocd
kubectl logs -n argocd deployment/argocd-repo-server
kubectl describe pod -n inference -l app.kubernetes.io/name=inference-gateway
kubectl describe rollout llm-inference-platform -n inference
kubectl logs -n argo-rollouts deployment/argo-rollouts
kubectl logs -n inference -l app.kubernetes.io/name=inference-gateway
```

If readiness fails while liveness succeeds, verify that Ollama is running on macOS and responds at `http://localhost:11434/v1/models`.
