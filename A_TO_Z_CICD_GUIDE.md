# A to Z CI/CD Guide - Simple Nginx App with Jenkins, Docker Hub, GitHub and kind

Ye guide ek fresher ke liye step-by-step likhi gayi hai. Isme hum samjhenge:

- Project kya hai
- CI/CD kya kar raha hai
- Kaunse issues aaye the
- Un issues ko kaise fix kiya gaya
- Windows aur Linux/Jenkins container environment me kya difference hota hai
- GitHub, Docker Hub, Jenkins credentials, kind cluster, Kubernetes deployment sab kaise setup karna hai
- Test aur Prod dono environment me deploy kaise karna hai

---

## 1. Final Architecture

```text
Developer laptop / Windows
        |
        | git push
        v
GitHub Repository
        |
        | Jenkins pulls Jenkinsfile
        v
Jenkins Container
        |
        | docker build
        v
Docker Image
        |
        | docker push
        v
Docker Hub Registry
        |
        | kubectl apply
        v
kind Kubernetes Clusters
        |
        | namespaces
        v
TEST and PROD Nginx App
```

---

## 2. Project Details

### GitHub Repository

```text
https://github.com/yogidiwe-rgb/simple-nginx-jenkins-lab.git
```

### Docker Hub Registry

```text
yogisre12345/simple-nginx-app
```

### Jenkins URL

```text
http://localhost:8888
```

### kind Contexts

```text
kind-test-cluster
kind-prod-cluster
```

### Kubernetes Namespaces

```text
test
prod
```

---

## 3. Project File Structure

```text
simple nginx jenkins lab
├── .dockerignore
├── .gitignore
├── A_TO_Z_CICD_GUIDE.md
├── Dockerfile
├── Dockerfile.jenkins
├── Jenkinsfile
├── README.md
├── index.html
└── k8s
    ├── base
    │   ├── deployment.yaml
    │   ├── kustomization.yaml
    │   └── service.yaml
    ├── prod
    │   └── kustomization.yaml
    └── test
        └── kustomization.yaml
```

---

## 4. Har File Ka Simple Meaning

### `index.html`

Ye Nginx app ka web page hai. Isme environment show hota hai:

```text
TEST
```

ya

```text
PROD
```

### `Dockerfile`

Ye app image banata hai. Important line:

```dockerfile
ARG APP_ENV=TEST
```

Jenkins build ke time `APP_ENV=TEST` ya `APP_ENV=PROD` pass karta hai.

### `Jenkinsfile`

Ye CI/CD pipeline hai. Jenkins isi file ko read karke stages run karta hai:

```text
Resolve Environment
Static Validation
Build & Tag
Push
Deploy
```

### `k8s/base`

Common Kubernetes files:

- Deployment
- Service

### `k8s/test`

Test environment overlay:

```text
namespace: test
image tag: test
replicas: 1
```

### `k8s/prod`

Prod environment overlay:

```text
namespace: prod
image tag: prod
replicas: 2
```

### `Dockerfile.jenkins`

Custom Jenkins image banane ke liye hai. Isme Jenkins ke andar ye tools install kiye gaye:

- Docker CLI
- kubectl

---

## 5. CI/CD Pipeline Flow

### Stage 1: Jenkins SCM Checkout

Jenkins GitHub se code pull karta hai.

```text
GitHub repo -> Jenkins workspace
```

### Stage 2: Resolve Environment

Agar `TARGET_ENV=test`, to Jenkins set karta hai:

```text
APP_ENV=TEST
IMAGE_TAG=test
KUBE_NAMESPACE=test
KUBE_CONTEXT=kind-test-cluster
```

Agar `TARGET_ENV=prod`, to Jenkins set karta hai:

```text
APP_ENV=PROD
IMAGE_TAG=prod
KUBE_NAMESPACE=prod
KUBE_CONTEXT=kind-prod-cluster
```

### Stage 3: Static Validation

Jenkins check karta hai:

```bash
docker --version
kubectl version --client=true
kubectl kustomize k8s/test
```

ya

```bash
kubectl kustomize k8s/prod
```

### Stage 4: Build & Tag

Test ke liye:

```bash
docker build --build-arg APP_ENV=TEST -t yogisre12345/simple-nginx-app:test .
```

Prod ke liye:

```bash
docker build --build-arg APP_ENV=PROD -t yogisre12345/simple-nginx-app:prod .
```

### Stage 5: Push

Docker Hub par image push hoti hai:

```bash
docker push yogisre12345/simple-nginx-app:test
```

ya

```bash
docker push yogisre12345/simple-nginx-app:prod
```

### Stage 6: Deploy

Jenkins Kubernetes cluster me deploy karta hai:

```bash
kubectl apply -f -
kubectl rollout status deployment/simple-nginx-app -n test
```

ya

```bash
kubectl rollout status deployment/simple-nginx-app -n prod
```

---

## 6. Issues Jo Aaye The Aur Fix Kaise Hue

## Issue 1: Jenkins me Docker Permission Denied

### Error

```text
docker: Permission denied
```

### Reason

Jenkins Docker container ke andar chal raha tha. Container ke paas host Docker daemon access nahi tha.

### Fix

Jenkins ko Docker socket ke saath restart kiya:

```powershell
-v /var/run/docker.sock:/var/run/docker.sock
```

Aur custom Jenkins image banayi jisme Docker CLI installed hai.

---

## Issue 2: Jenkins Container me `kubectl` Missing Ya Not Ready

### Reason

Default Jenkins image me `kubectl` installed nahi hota.

### Fix

`Dockerfile.jenkins` banaya:

```dockerfile
FROM jenkins/jenkins:lts-jdk17

USER root

RUN apt-get update \
    && apt-get install -y ca-certificates curl gnupg lsb-release \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && curl -LO "https://dl.k8s.io/release/v1.32.0/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER jenkins
```

---

## Issue 3: Jenkins ko kind Cluster Dikh Raha Tha Par Connect Nahi Ho Raha Tha

### Error

```text
The connection to the server 127.0.0.1:51661 was refused
```

### Reason

Windows host par kubeconfig me API server tha:

```text
https://127.0.0.1:51661
```

Lekin Jenkins container ke andar `127.0.0.1` ka matlab Jenkins container khud hota hai, Windows host nahi.

### Fix

Jenkins ko Docker `kind` network me attach kiya:

```powershell
docker network connect kind jenkins-server
```

Phir internal kubeconfig banaya jisme API server direct kind control-plane container names se point kare:

```text
https://test-cluster-control-plane:6443
https://prod-cluster-control-plane:6443
```

Final Jenkins run me environment variable diya:

```powershell
-e KUBECONFIG=/var/jenkins_home/.kube/config-internal
```

---

## Issue 4: GitHub Placeholder URL Error

### Error

```text
fatal: repository 'https://github.com/GITHUB_USERNAME/simple-nginx-app.git/' not found
```

### Reason

Jenkinsfile me duplicate Checkout stage tha jo old parameter `GIT_REPO_URL` use kar raha tha.

### Fix

Duplicate Checkout stage remove kiya. Jenkins already SCM se checkout karta hai.

---

## Issue 5: Kustomize Overlay Error

### Error

```text
security; file ... is not in or below ...
```

### Reason

Overlay directly files refer kar raha tha:

```yaml
resources:
  - ../base/deployment.yaml
  - ../base/service.yaml
```

Kustomize ko base directory as resource chahiye thi.

### Fix

`k8s/base/kustomization.yaml` add kiya:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
```

Overlay update kiya:

```yaml
resources:
  - ../base
```

---

## 7. Windows vs Linux Difference

## Windows Host

Aapka laptop Windows hai. Commands mostly PowerShell me chalenge.

Example:

```powershell
docker ps
kubectl config get-contexts
kind get clusters
```

PowerShell me line continuation ke liye backtick use hota hai:

```powershell
docker run -d `
  --name jenkins-server `
  -p 8888:8080 `
  jenkins/jenkins:lts
```

## Linux / Jenkins Container

Jenkins container Linux environment hai. Isme commands shell style me hoti hain:

```bash
docker --version
kubectl get nodes
```

Linux me line continuation ke liye backslash use hota hai:

```bash
docker run -d \
  --name jenkins-server \
  -p 8888:8080 \
  jenkins/jenkins:lts
```

## Jenkinsfile Cross-Platform Fix

Jenkinsfile me helper function hai:

```groovy
def runCmd(String command, boolean returnStatus = false) {
    if (isUnix()) {
        return sh(script: command, returnStatus: returnStatus)
    }
    return powershell(script: command, returnStatus: returnStatus)
}
```

Iska matlab:

- Jenkins Linux agent par `sh` use karega
- Jenkins Windows agent par `powershell` use karega

---

## 8. Fresh Setup - A to Z Commands

## Step 1: Required Tools Install Karo

Windows machine par ye tools hone chahiye:

- Docker Desktop
- Git
- kubectl
- kind
- VS Code / IDE

Check:

```powershell
git --version
docker --version
kubectl version --client=true
kind version
```

---

## Step 2: GitHub Repo Clone Ya Project Folder Open Karo

```powershell
git clone https://github.com/yogidiwe-rgb/simple-nginx-jenkins-lab.git
```

Project folder me jao:

```powershell
cd "f:\simple lab Day 1\simple nginx jenkins lab"
```

Status check:

```powershell
git status
```

---

## Step 3: kind Clusters Create Karo

Agar clusters already nahi hain:

```powershell
kind create cluster --name test-cluster
kind create cluster --name prod-cluster
```

Check:

```powershell
kind get clusters
kubectl config get-contexts
```

Expected contexts:

```text
kind-test-cluster
kind-prod-cluster
```

---

## Step 4: Namespaces Create Karo

```powershell
kubectl --context kind-test-cluster create namespace test --dry-run=client -o yaml | kubectl --context kind-test-cluster apply -f -
kubectl --context kind-prod-cluster create namespace prod --dry-run=client -o yaml | kubectl --context kind-prod-cluster apply -f -
```

Verify:

```powershell
kubectl --context kind-test-cluster get ns test
kubectl --context kind-prod-cluster get ns prod
```

---

## Step 5: Custom Jenkins Image Build Karo

Project root se:

```powershell
docker build -f Dockerfile.jenkins -t local/jenkins-docker-kubectl:lts-jdk17 .
```

Verify:

```powershell
docker images | Select-String jenkins-docker-kubectl
```

---

## Step 6: Jenkins Container Start Karo

Agar old Jenkins container hai:

```powershell
docker stop jenkins-server
docker rm jenkins-server
```

Start Jenkins:

```powershell
docker run -d `
  --name jenkins-server `
  --network kind `
  -p 8888:8080 `
  -p 50000:50000 `
  -v jenkins_jenkins_home:/var/jenkins_home `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v ${env:USERPROFILE}\.kube:/var/jenkins_home/.kube `
  -e KUBECONFIG=/var/jenkins_home/.kube/config-internal `
  -u root `
  local/jenkins-docker-kubectl:lts-jdk17
```

Agar first time Jenkins start ho raha hai, initial password dekho:

```powershell
docker exec jenkins-server cat /var/jenkins_home/secrets/initialAdminPassword
```

Browser me open karo:

```text
http://localhost:8888
```

---

## Step 7: Internal Kubeconfig Create Karo

Agar `config-internal` nahi bana hai, ye command run karo:

```powershell
docker exec jenkins-server sh -c "cp /var/jenkins_home/.kube/config /var/jenkins_home/.kube/config-internal && sed -i 's#https://127.0.0.1:51661#https://test-cluster-control-plane:6443#g' /var/jenkins_home/.kube/config-internal && sed -i 's#https://127.0.0.1:64269#https://prod-cluster-control-plane:6443#g' /var/jenkins_home/.kube/config-internal"
```

Important: Ports `51661` and `64269` aapke system me different ho sakte hain. Current values check karne ke liye:

```powershell
kubectl config view --minify=false
```

Ya exact server lines:

```powershell
kubectl config view -o jsonpath='{.clusters[*].cluster.server}'
```

Phir Jenkins restart karo:

```powershell
docker stop jenkins-server
docker rm jenkins-server
```

```powershell
docker run -d `
  --name jenkins-server `
  --network kind `
  -p 8888:8080 `
  -p 50000:50000 `
  -v jenkins_jenkins_home:/var/jenkins_home `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v ${env:USERPROFILE}\.kube:/var/jenkins_home/.kube `
  -e KUBECONFIG=/var/jenkins_home/.kube/config-internal `
  -u root `
  local/jenkins-docker-kubectl:lts-jdk17
```

---

## Step 8: Jenkins Container Verification

```powershell
docker exec jenkins-server docker --version
docker exec jenkins-server kubectl version --client=true
docker exec jenkins-server kubectl config get-contexts
docker exec jenkins-server kubectl --context kind-test-cluster get nodes
docker exec jenkins-server kubectl --context kind-prod-cluster get nodes
```

Expected:

```text
Docker version ...
Client Version ...
kind-test-cluster
kind-prod-cluster
Ready nodes
```

---

## 9. Jenkins GUI Setup

## Step 1: Jenkins Open Karo

Browser:

```text
http://localhost:8888
```

## Step 2: Plugins Check Karo

GUI path:

```text
Manage Jenkins -> Plugins -> Installed plugins
```

Required plugins:

- Pipeline
- Git
- Credentials Binding

Agar missing ho:

```text
Manage Jenkins -> Plugins -> Available plugins
```

Search karke install karo.

---

## Step 3: Docker Hub Credential Add Karo

GUI path:

```text
Manage Jenkins -> Credentials -> System -> Global credentials -> Add Credentials
```

Values:

```text
Kind: Username with password
Scope: Global
Username: yogisre12345
Password: Docker Hub Access Token
ID: dockerhub-credentials
Description: Docker Hub credentials for pipeline
```

Important:

- Docker Hub password mat use karo
- Docker Hub Access Token use karo

Docker Hub token path:

```text
Docker Hub -> Account Settings -> Personal access tokens -> Generate new token
```

---

## Step 4: GitHub Credential Add Karo

GUI path:

```text
Manage Jenkins -> Credentials -> System -> Global credentials -> Add Credentials
```

Values:

```text
Kind: Username with password
Scope: Global
Username: yogidiwe-rgb
Password: GitHub Personal Access Token
ID: github-credentials
Description: GitHub credentials for checkout
```

GitHub token path:

```text
GitHub -> Settings -> Developer settings -> Personal access tokens
```

Minimum permission:

```text
Repository contents: Read
```

---

## Step 5: Jenkins Pipeline Job Create Karo

GUI path:

```text
Jenkins Dashboard -> New Item
```

Name:

```text
nginx cicd
```

Select:

```text
Pipeline
```

Click:

```text
OK
```

---

## Step 6: Pipeline from SCM Configure Karo

GUI path:

```text
Job -> Configure -> Pipeline
```

Values:

```text
Definition: Pipeline script from SCM
SCM: Git
Repository URL: https://github.com/yogidiwe-rgb/simple-nginx-jenkins-lab.git
Credentials: github-credentials
Branch Specifier: */main
Script Path: Jenkinsfile
```

Click:

```text
Save
```

---

## 10. Jenkins TEST Deployment Run

GUI path:

```text
Jenkins Dashboard -> nginx cicd -> Build with Parameters
```

Values:

```text
TARGET_ENV: test
DOCKERHUB_REPO: yogisre12345/simple-nginx-app
GIT_BRANCH: main
TEST_KUBE_CONTEXT: kind-test-cluster
PROD_KUBE_CONTEXT: kind-prod-cluster
```

Click:

```text
Build
```

Expected pipeline stages:

```text
Declarative: Checkout SCM
Resolve Environment
Static Validation
Build & Tag
Push
Deploy
```

Expected image:

```text
yogisre12345/simple-nginx-app:test
```

Expected Kubernetes deployment:

```text
Cluster: kind-test-cluster
Namespace: test
Deployment: simple-nginx-app
```

---

## 11. Jenkins PROD Deployment Run

GUI path:

```text
Jenkins Dashboard -> nginx cicd -> Build with Parameters
```

Values:

```text
TARGET_ENV: prod
DOCKERHUB_REPO: yogisre12345/simple-nginx-app
GIT_BRANCH: main
TEST_KUBE_CONTEXT: kind-test-cluster
PROD_KUBE_CONTEXT: kind-prod-cluster
```

Click:

```text
Build
```

Expected image:

```text
yogisre12345/simple-nginx-app:prod
```

Expected Kubernetes deployment:

```text
Cluster: kind-prod-cluster
Namespace: prod
Deployment: simple-nginx-app
```

---

## 12. Verify Deployment from Windows PowerShell

## TEST Verify

```powershell
kubectl --context kind-test-cluster get all -n test
kubectl --context kind-test-cluster rollout status deployment/simple-nginx-app -n test
```

Port forward:

```powershell
kubectl --context kind-test-cluster port-forward svc/simple-nginx-app 8080:80 -n test
```

Browser:

```text
http://localhost:8080
```

Expected page:

```text
TEST
```

Stop port-forward:

```text
CTRL + C
```

## PROD Verify

```powershell
kubectl --context kind-prod-cluster get all -n prod
kubectl --context kind-prod-cluster rollout status deployment/simple-nginx-app -n prod
```

Port forward:

```powershell
kubectl --context kind-prod-cluster port-forward svc/simple-nginx-app 8081:80 -n prod
```

Browser:

```text
http://localhost:8081
```

Expected page:

```text
PROD
```

---

## 13. Verify Docker Hub Image

Docker Hub browser path:

```text
https://hub.docker.com/repository/docker/yogisre12345/simple-nginx-app/tags
```

Expected tags:

```text
test
prod
```

Command line verify:

```powershell
docker pull yogisre12345/simple-nginx-app:test
docker pull yogisre12345/simple-nginx-app:prod
```

---

## 14. Common Errors and Fixes

## Error: `docker: Permission denied`

### Fix

Jenkins ko Docker socket mount ke saath run karo:

```powershell
-v /var/run/docker.sock:/var/run/docker.sock
-u root
```

---

## Error: `docker: not found`

### Fix

Custom Jenkins image build karo:

```powershell
docker build -f Dockerfile.jenkins -t local/jenkins-docker-kubectl:lts-jdk17 .
```

---

## Error: `kubectl: not found`

### Fix

Same custom Jenkins image use karo jisme kubectl installed hai.

---

## Error: `repository not found GITHUB_USERNAME`

### Fix

Jenkins job SCM URL correct karo:

```text
Job -> Configure -> Pipeline -> Repository URL
```

Use:

```text
https://github.com/yogidiwe-rgb/simple-nginx-jenkins-lab.git
```

---

## Error: `unauthorized: incorrect username or password`

### Fix

Docker Hub credential check karo:

```text
Manage Jenkins -> Credentials -> System -> Global credentials
```

Credential ID must be:

```text
dockerhub-credentials
```

Username:

```text
yogisre12345
```

Password:

```text
Docker Hub Access Token
```

---

## Error: `The connection to the server 127.0.0.1 was refused`

### Fix

Jenkins container ke liye internal kubeconfig use karo:

```text
/var/jenkins_home/.kube/config-internal
```

Jenkins run command me:

```powershell
-e KUBECONFIG=/var/jenkins_home/.kube/config-internal
--network kind
```

---

## Error: `ImagePullBackOff`

### Check

```powershell
kubectl --context kind-test-cluster describe pod -n test
```

Common reasons:

- Docker Hub image push nahi hui
- Image private hai
- Tag galat hai
- Docker Hub repo name galat hai

Expected images:

```text
yogisre12345/simple-nginx-app:test
yogisre12345/simple-nginx-app:prod
```

---

## 15. Useful Daily Commands

## Jenkins Logs

```powershell
docker logs -f jenkins-server
```

## Enter Jenkins Container

```powershell
docker exec -it jenkins-server bash
```

## Check Running Containers

```powershell
docker ps
```

## Check kind Clusters

```powershell
kind get clusters
```

## Check Kubernetes Contexts

```powershell
kubectl config get-contexts
```

## Check Test App

```powershell
kubectl --context kind-test-cluster get all -n test
```

## Check Prod App

```powershell
kubectl --context kind-prod-cluster get all -n prod
```

---

## 16. Clean Restart Jenkins

```powershell
docker stop jenkins-server
docker rm jenkins-server
```

```powershell
docker run -d `
  --name jenkins-server `
  --network kind `
  -p 8888:8080 `
  -p 50000:50000 `
  -v jenkins_jenkins_home:/var/jenkins_home `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v ${env:USERPROFILE}\.kube:/var/jenkins_home/.kube `
  -e KUBECONFIG=/var/jenkins_home/.kube/config-internal `
  -u root `
  local/jenkins-docker-kubectl:lts-jdk17
```

---

## 17. Fresh Machine Full Order

Agar ekdum fresh setup karna ho to order ye rakho:

1. Docker Desktop install
2. Git install
3. kubectl install
4. kind install
5. GitHub repo clone
6. kind test cluster create
7. kind prod cluster create
8. namespaces create
9. custom Jenkins image build
10. Jenkins container run
11. internal kubeconfig create
12. Jenkins credentials add
13. Jenkins pipeline job create
14. TEST pipeline run
15. TEST verify
16. PROD pipeline run
17. PROD verify
18. Docker Hub tags verify

---

## 18. L5 Engineer Improvements Later

Abhi pipeline simple hai. Future me professional level ke liye ye add kar sakte ho:

- Dockerfile linting using Hadolint
- Kubernetes YAML validation
- Container smoke test before push
- Trivy image vulnerability scan
- Commit SHA based immutable image tags
- Manual approval before prod deployment
- Build once, promote same image digest to prod
- GitOps with Argo CD or Flux
- Monitoring with Prometheus and Grafana
- Logs with Loki or ELK

---

## 19. Quick Final Test Checklist

Before saying deployment successful, ye check karo:

```powershell
docker exec jenkins-server docker --version
docker exec jenkins-server kubectl --context kind-test-cluster get nodes
docker exec jenkins-server kubectl --context kind-prod-cluster get nodes
```

Then Jenkins me:

```text
Build with Parameters -> TARGET_ENV=test
```

Then:

```text
Build with Parameters -> TARGET_ENV=prod
```

Then verify:

```powershell
kubectl --context kind-test-cluster get pods -n test
kubectl --context kind-prod-cluster get pods -n prod
```

Agar pods `Running` hain aur browser me TEST/PROD dikh raha hai, CI/CD successful hai.

---

## 20. Important GUI Paths Summary

```text
Jenkins URL:
http://localhost:8888
```

```text
Plugin install/check:
Manage Jenkins -> Plugins
```

```text
Credentials:
Manage Jenkins -> Credentials -> System -> Global credentials
```

```text
New job:
Jenkins Dashboard -> New Item -> Pipeline
```

```text
Job config:
Jenkins Dashboard -> nginx cicd -> Configure
```

```text
Pipeline SCM config:
Configure -> Pipeline -> Definition: Pipeline script from SCM
```

```text
Run build:
Jenkins Dashboard -> nginx cicd -> Build with Parameters
```

```text
Console logs:
Jenkins Dashboard -> nginx cicd -> Build Number -> Console Output
```

---

# Final Summary

Is project me humne ek complete local CI/CD ecosystem banaya:

- GitHub se code checkout
- Jenkins pipeline execution
- Docker image build
- Docker Hub push
- kind test cluster deploy
- kind prod cluster deploy
- TEST/PROD environment injection
- Kubernetes manifests using Kustomize
- Jenkins runtime fix with Docker and kubectl

Agar koi error aaye, sabse pehle Jenkins Console Output dekho aur is guide ke `Common Errors and Fixes` section se match karo.
