# EKS & GitHub Actions Setup Guide

Complete guide to set up the GitHub Actions CI/CD pipeline with an AWS EKS cluster for this project.

---

## Prerequisites

### CLI Tools

```bash
brew install awscli eksctl kubectl
```

### AWS Credentials

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-2), Output format (json)
```

---

## Part 1: GitHub Actions CI/CD

CI/CD is configured via GitHub Actions workflows in `.github/workflows/`:

| Workflow | File | Trigger |
|----------|------|---------|
| **CI** | `ci.yml` | Push & PR to `master`/`main` — runs backend build, lint, test, coverage + frontend build |
| **Docker Build & Push** | `docker-publish.yml` | Push to `master`/`main` — builds multi-arch images and pushes to GHCR |
| **Deploy** | `deploy.yml` | After Docker Build & Push succeeds — deploys to staging, runs E2E tests, then production (with manual approval) |

### 1.1 Required GitHub Actions Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|--------|-------------|
| `KUBECONFIG_STAGING` | Base64-encoded kubeconfig for the staging K8s cluster |
| `KUBECONFIG_PRODUCTION` | Base64-encoded kubeconfig for the production K8s cluster |

> **Note**: `GITHUB_TOKEN` is automatically available and is used for GHCR authentication — no additional registry credentials are needed.

### 1.2 Required GitHub Environments

Go to **Settings → Environments** and configure:

| Environment | Protection Rules |
|-------------|-----------------|
| `staging` | None (auto-deploys) |
| `production` | Required reviewers (add team members who can approve production deploys) |

### 1.3 Container Registry

Docker images are published to **GitHub Container Registry (GHCR)** at:

- **Backend**: `ghcr.io/mbatchelor81/gitlab-migration/backend`
- **Frontend**: `ghcr.io/mbatchelor81/gitlab-migration/frontend`

Images are tagged with the short commit SHA and `latest`.

---

## Part 2: EKS Cluster

### 2.1 Create the Cluster

This takes ~15-20 minutes:

```bash
eksctl create cluster \
  --name realworld-demo \
  --region us-east-2 \
  --node-type t3.medium \
  --nodes 2 \
  --managed
```

### 2.2 Create Namespaces

```bash
kubectl create namespace realworld-staging
kubectl create namespace realworld
```

### 2.3 Create GHCR Registry Pull Secrets

If using private GHCR packages, create a GitHub Personal Access Token with `read:packages` scope:

```bash
kubectl create secret docker-registry ghcr-registry-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-pat> \
  -n realworld-staging

kubectl create secret docker-registry ghcr-registry-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-pat> \
  -n realworld
```

> The secret name `ghcr-registry-secret` must match the `imagePullSecrets` in `k8s/backend-deployment.yaml` and `k8s/frontend-deployment.yaml`.

### 2.4 Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/aws/deploy.yaml
```

### 2.5 Export Kubeconfig for GitHub Actions

Both staging and production use the same cluster (different namespaces):

```bash
kubectl config view --raw > /tmp/kubeconfig
cat /tmp/kubeconfig | base64 | tr -d '\n' > /tmp/kubeconfig-b64
```

Add the base64-encoded kubeconfig as both `KUBECONFIG_STAGING` and `KUBECONFIG_PRODUCTION` secrets in GitHub Actions (see Part 1).

### 2.6 Trigger a Deploy

Push or merge to the `master` branch. The CI workflow will run first, followed by Docker Build & Push, then the Deploy workflow will:

1. Deploy to staging automatically
2. Run E2E Selenium tests against staging
3. Wait for manual approval in the `production` environment
4. Deploy to production after approval

---

## Teardown

### Delete EKS Cluster

```bash
eksctl delete cluster --name realworld-demo --region us-east-2 --wait
```

> The `--wait` flag ensures the command blocks until all CloudFormation stacks (nodegroup + control plane) are fully deleted. Without it, the control plane deletion runs async and may appear to still exist.

---

## Quick Reference

| Item                       | Value                                                                 |
|----------------------------|-----------------------------------------------------------------------|
| Container Registry         | `ghcr.io/mbatchelor81/gitlab-migration`                               |
| CI Workflow                | `.github/workflows/ci.yml`                                            |
| Docker Workflow            | `.github/workflows/docker-publish.yml`                                |
| Deploy Workflow            | `.github/workflows/deploy.yml`                                        |
| EKS Cluster Name           | `realworld-demo`                                                      |
| AWS Region                 | `us-east-2`                                                           |
| Staging Namespace          | `realworld-staging`                                                   |
| Production Namespace       | `realworld`                                                           |
| GitHub Actions Secrets     | `KUBECONFIG_STAGING`, `KUBECONFIG_PRODUCTION`                         |
| GitHub Environments        | `staging`, `production` (with required reviewers)                     |
