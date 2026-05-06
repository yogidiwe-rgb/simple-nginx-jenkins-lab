# Simple Nginx Jenkins Kubernetes CI/CD Lab

This repository contains a complete starter CI/CD ecosystem for a simple Nginx application.

## Architecture

- **Application:** Nginx serving a custom `index.html`.
- **Environment injection:** Docker build argument `APP_ENV` injects `TEST` or `PROD` into the generated HTML.
- **Image registry:** Docker Hub.
- **CI/CD:** Jenkins declarative pipeline.
- **Deployment:** Kubernetes manifests with Kustomize overlays for `test` and `prod`.
- **Local clusters:** Designed for local `kind` contexts such as `kind-test` and `kind-prod`.

## Repository Structure

```text
.
├── Dockerfile
├── Jenkinsfile
├── index.html
├── k8s
│   ├── base
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── prod
│   │   └── kustomization.yaml
│   └── test
│       └── kustomization.yaml
├── .dockerignore
├── .gitignore
└── README.md
```

## Local Git Setup

Run these commands from the repository root:

```powershell
git init
git add .
git commit -m "Initial CI/CD lab scaffold"
git branch -M main
git remote add origin https://github.com/<github-username>/<repo-name>.git
git push -u origin main
```

## Local Docker Build

Build a test image:

```powershell
docker build --build-arg APP_ENV=TEST -t <dockerhub-username>/simple-nginx-app:test .
```

Build a prod image:

```powershell
docker build --build-arg APP_ENV=PROD -t <dockerhub-username>/simple-nginx-app:prod .
```

Run locally:

```powershell
docker run --rm -p 8080:80 <dockerhub-username>/simple-nginx-app:test
```

Open `http://localhost:8080`.

## Kubernetes Namespace Commands

For one shared cluster:

```powershell
kubectl create namespace test
kubectl create namespace prod
```

For separate local `kind` clusters:

```powershell
kubectl --context kind-test create namespace test
kubectl --context kind-prod create namespace prod
```

Idempotent version:

```powershell
kubectl --context kind-test create namespace test --dry-run=client -o yaml | kubectl --context kind-test apply -f -
kubectl --context kind-prod create namespace prod --dry-run=client -o yaml | kubectl --context kind-prod apply -f -
```

## Manual Kubernetes Deploy

Render test manifests:

```powershell
kubectl kustomize k8s/test
```

Deploy test:

```powershell
kubectl --context kind-test kustomize k8s/test | kubectl --context kind-test apply -f -
kubectl --context kind-test rollout status deployment/simple-nginx-app -n test
```

Deploy prod:

```powershell
kubectl --context kind-prod kustomize k8s/prod | kubectl --context kind-prod apply -f -
kubectl --context kind-prod rollout status deployment/simple-nginx-app -n prod
```

Before manual deployment, replace `DOCKERHUB_USERNAME/simple-nginx-app` in the Kustomize overlays or use the Jenkins pipeline parameter `DOCKERHUB_REPO`.

## Jenkins Credentials

Create credentials from **Manage Jenkins → Credentials → System → Global credentials**.

### Docker Hub

- **Kind:** Username with password.
- **ID:** `dockerhub-credentials`.
- **Username:** Your Docker Hub username.
- **Password:** A Docker Hub access token, not your account password.

The Jenkinsfile uses:

```groovy
withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_TOKEN')])
```

### GitHub

Recommended options:

- **HTTPS token:** Username with password, ID `github-credentials`, username is your GitHub username, password is a fine-grained Personal Access Token.
- **SSH key:** SSH Username with private key, then change `GIT_REPO_URL` to the SSH URL and adjust the Jenkins checkout configuration if needed.

For private repositories, the token needs repository read access. For pushing tags or releases later, grant only the minimum required write permissions.

## Jenkins Pipeline Parameters

- **`TARGET_ENV`:** `auto`, `test`, or `prod`.
- **`DOCKERHUB_REPO`:** Example: `<dockerhub-username>/simple-nginx-app`.
- **`GIT_REPO_URL`:** Your GitHub repository URL.
- **`GIT_BRANCH`:** Branch to build.
- **`TEST_KUBE_CONTEXT`:** Default `kind-test`.
- **`PROD_KUBE_CONTEXT`:** Default `kind-prod`.

When `TARGET_ENV=auto`, `main` and `master` deploy to `prod`; all other branches deploy to `test`.

## Jenkins Agent Requirements

The Jenkins agent must have:

- Docker CLI and access to a Docker daemon.
- `kubectl` configured with access to your local kind contexts.
- Network access to Docker Hub and GitHub.
- Permission to run Docker builds and Kubernetes deployments.

## L5-Level Scaling Roadmap

The Jenkinsfile already includes a `Static Validation` stage. You can grow this into a production-grade pipeline by adding:

- **HTML/container linting:** `hadolint`, `htmlhint`, and YAML validation.
- **Unit/smoke tests:** Run container and `curl` the app before pushing.
- **Security scanning:** Trivy or Grype image vulnerability scans.
- **SBOM:** Generate CycloneDX or SPDX SBOMs.
- **Immutable tags:** Add commit SHA tags such as `simple-nginx-app:test-${GIT_COMMIT}`.
- **Promotion model:** Build once, promote the same digest from test to prod.
- **Policy gates:** OPA/Conftest checks for Kubernetes manifests.
- **GitOps:** Move deployment ownership to Argo CD or Flux.
- **Observability:** Add Prometheus scrape annotations, logs, and SLO dashboards.
