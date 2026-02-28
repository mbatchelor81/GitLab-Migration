# EKS & Jenkins Setup Guide

Complete guide to set up the Jenkins CI/CD pipeline with an AWS EKS cluster for this project.

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

### GitLab Access Token

Create a **Project Access Token** in GitLab for Docker registry access:

1. Go to **GitLab → Project → Settings → Access Tokens**
2. **Token name**: `jenkins-registry`
3. **Role**: **Developer** (minimum for push — Guest will not work)
4. **Scopes**: `read_registry`, `write_registry`, `read_api`
5. Copy the token immediately

---

## Part 1: Jenkins (Local Docker)

### 1.1 Start Jenkins

```bash
./scripts/jenkins-local.sh start
```

This builds a custom Jenkins image (`scripts/jenkins.Dockerfile`) with Docker CLI, JDK 11, kubectl, AWS CLI, and Chromium pre-installed. Data persists in the `jenkins_demo_home` Docker volume.

### 1.2 Unlock Jenkins

```bash
./scripts/jenkins-local.sh password
```

Go to **http://localhost:8080** and paste the password.

### 1.3 Install Plugins

- Choose **"Install suggested plugins"**
- After setup, install the **NodeJS plugin**: **Manage Jenkins → Plugins → Available plugins** → search "NodeJS" → install

### 1.4 Configure Tools

Go to **Manage Jenkins → Tools**:

| Tool    | Name        | Config                                                      |
|---------|-------------|-------------------------------------------------------------|
| JDK     | `JDK-11`    | Uncheck "Install automatically", JAVA_HOME = `/opt/java/jdk-11` |
| Gradle  | `Gradle-7.4`| Check "Install automatically", version 7.4                  |
| NodeJS  | `Node-16`   | Check "Install automatically", version 16.x                 |

> **Names must match exactly** — they are referenced in the `Jenkinsfile`.

### 1.5 Add GitLab Registry Credentials

Go to **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**:

- **Kind**: Username with password
- **Scope**: Global
- **Username**: your GitLab username (e.g. `mason-cognition`)
- **Password**: the GitLab Project Access Token from Prerequisites
- **ID**: `gitlab-registry-credentials`
- **Description**: `GitLab Container Registry`

### 1.6 Create Multibranch Pipeline Job

1. **Dashboard → New Item** → name: `realworld-app` → select **Multibranch Pipeline** → OK
2. Under **Branch Sources** → **Add source** → **Git**:
   - **Project Repository**: `https://gitlab.com/mason-cognition/spring-boot-realworld-example-app.git`
   - **Credentials**: select `gitlab-registry-credentials`
3. Under **Build Configuration**:
   - **Mode**: `by Jenkinsfile`
   - **Script Path**: `Jenkinsfile`
4. Click **Save** — Jenkins will scan branches and trigger a build

At this point, CI stages (build, lint, test, Docker build/push) will work. Deploy stages will fail until EKS is configured.

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

### 2.3 Create GitLab Registry Pull Secrets

Replace `<gitlab-username>` and `<gitlab-token>` with your actual values:

```bash
kubectl create secret docker-registry gitlab-registry-secret \
  --docker-server=registry.gitlab.com \
  --docker-username=<gitlab-username> \
  --docker-password=<gitlab-token> \
  -n realworld-staging

kubectl create secret docker-registry gitlab-registry-secret \
  --docker-server=registry.gitlab.com \
  --docker-username=<gitlab-username> \
  --docker-password=<gitlab-token> \
  -n realworld
```

> The secret name `gitlab-registry-secret` must match the `imagePullSecrets` in `k8s/backend-deployment.yaml` and `k8s/frontend-deployment.yaml`.

### 2.4 Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/aws/deploy.yaml
```

### 2.5 Export Kubeconfig for Jenkins

Both staging and production use the same cluster (different namespaces):

```bash
kubectl config view --raw > /tmp/kubeconfig-staging
cp /tmp/kubeconfig-staging /tmp/kubeconfig-production
```

### 2.6 Add Kubeconfig Credentials to Jenkins

Go to **Manage Jenkins → Credentials → System → Global credentials → Add Credentials** (repeat for each):

| Kind        | File to upload               | ID                      |
|-------------|------------------------------|-------------------------|
| Secret file | `/tmp/kubeconfig-staging`    | `kubeconfig-staging`    |
| Secret file | `/tmp/kubeconfig-production` | `kubeconfig-production` |

### 2.7 Re-run the Pipeline

Go to the `realworld-app` job in Jenkins and click **Build Now**. All stages including deploy should now pass.

---

## Teardown

### Delete EKS Cluster

```bash
eksctl delete cluster --name realworld-demo --region us-east-2 --wait
```

> The `--wait` flag ensures the command blocks until all CloudFormation stacks (nodegroup + control plane) are fully deleted. Without it, the control plane deletion runs async and may appear to still exist.

### Stop Jenkins

```bash
./scripts/jenkins-local.sh stop
```

### Full Jenkins Cleanup (removes all data)

```bash
./scripts/jenkins-local.sh stop
docker rm jenkins-demo
docker volume rm jenkins_demo_home
```

---

## Jenkins Script Console Helpers

Access at **http://localhost:8080/script**.

### Reset Build Numbers

```groovy
def job = Jenkins.instance.getItemByFullName('realworld-app/master')
job.builds.each { it.delete() }
job.updateNextBuildNumber(1)
println "Done"
```

---

## Quick Reference

| Item                       | Value                                                                 |
|----------------------------|-----------------------------------------------------------------------|
| Jenkins URL                | http://localhost:8080                                                  |
| GitLab Registry            | `registry.gitlab.com/mason-cognition/spring-boot-realworld-example-app` |
| EKS Cluster Name           | `realworld-demo`                                                      |
| AWS Region                 | `us-east-2`                                                           |
| Staging Namespace          | `realworld-staging`                                                   |
| Production Namespace       | `realworld`                                                           |
| Jenkins Credential IDs     | `gitlab-registry-credentials`, `kubeconfig-staging`, `kubeconfig-production` |
| Jenkins Tool Names         | `JDK-11`, `Gradle-7.4`, `Node-16`                                    |
