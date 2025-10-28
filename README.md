# BeMind Kubernetes Deployment

A production-ready Kubernetes deployment for the BeMind indexing and API system on Azure Kubernetes Service (AKS).

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Guide](#deployment-guide)
- [API Reference](#api-reference)
- [Testing](#testing)
- [Monitoring & Troubleshooting](#monitoring--troubleshooting)
- [Cleanup](#cleanup)

## 🎯 Overview

BeMind is a cloud-native application that provides:
- **RESTful API** for managing document indexing jobs
- **Kubernetes Job Management** with parallelism and retry logic
- **Azure Integration** with Storage, Cognitive Search, and OpenAI
- **Production-ready** deployment with health checks, autoscaling, and monitoring

### Key Features

- ✅ Horizontal Pod Autoscaling (HPA)
- ✅ Rolling updates with zero downtime
- ✅ Health and readiness probes
- ✅ Secure secret management
- ✅ Resource limits and requests
- ✅ RBAC for job creation
- ✅ Multi-stage Docker builds
- ✅ Azure Container Registry (ACR) integration

## 🏗️ Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────┐
│                     Azure Cloud                         │
│  ┌────────────────────────────────────────────────┐    │
│  │            Azure Kubernetes Service             │    │
│  │                                                 │    │
│  │  ┌──────────────┐      ┌──────────────┐       │    │
│  │  │   BeMind API │◄────►│  Kubernetes  │       │    │
│  │  │  (Deployment)│      │    Jobs      │       │    │
│  │  └──────┬───────┘      └──────────────┘       │    │
│  │         │                                       │    │
│  │         ▼                                       │    │
│  │  ┌──────────────┐                              │    │
│  │  │ Load Balancer│                              │    │
│  │  └──────────────┘                              │    │
│  └────────────────────────────────────────────────┘    │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │  Storage │  │  Search  │  │  OpenAI  │            │
│  │   Blob   │  │ Service  │  │ Service  │            │
│  └──────────┘  └──────────┘  └──────────┘            │
└─────────────────────────────────────────────────────────┘
```

### Request Flow Through Load Balancer

This diagram shows the complete request flow from external clients through the Azure Load Balancer to the API pods and backend services:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          EXTERNAL CLIENTS                                 │
│     (curl, Postman, Web Apps, Mobile Apps)                               │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
                                │ HTTP Request (Port 80)
                                │ GET /health, POST /api/jobs, etc.
                                ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                      AZURE LOAD BALANCER                                  │
│  • Public IP: Dynamically assigned                                        │
│  • Health Probe: /health (every 5 seconds)                                │
│  • Session Affinity: ClientIP (1 hour timeout)                            │
│  • Port Mapping: 80 (external) → 5002 (internal)                          │
└───────────────────────────────┬───────────────────────────────────────────┘
                                │
                                │ Routes to healthy pods only
                                │ Distributes load across available pods
                                ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                   KUBERNETES SERVICE (LoadBalancer)                       │
│  • Name: bemind-api-service                                               │
│  • Type: LoadBalancer                                                     │
│  • Selector: app=bemind-api, component=api                                │
│  • Port: 80 → TargetPort: 5002                                            │
└───────────────────────────────┬───────────────────────────────────────────┘
                                │
                                │ Service discovers and routes to pods
                                │ Based on label selectors
                                ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                    KUBERNETES API PODS (2-10 replicas)                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │
│  │   Pod 1         │  │   Pod 2         │  │   Pod N         │          │
│  │                 │  │                 │  │                 │          │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │          │
│  │ │  Gunicorn   │ │  │ │  Gunicorn   │ │  │ │  Gunicorn   │ │          │
│  │ │  (WSGI)     │ │  │ │  (WSGI)     │ │  │ │  (WSGI)     │ │          │
│  │ │  2 workers  │ │  │ │  2 workers  │ │  │ │  2 workers  │ │          │
│  │ │  4 threads  │ │  │ │  4 threads  │ │  │ │  4 threads  │ │          │
│  │ └──────┬──────┘ │  │ └──────┬──────┘ │  │ └──────┬──────┘ │          │
│  │        │        │  │        │        │  │        │        │          │
│  │ ┌──────▼──────┐ │  │ ┌──────▼──────┐ │  │ ┌──────▼──────┐ │          │
│  │ │  Flask App  │ │  │ │  Flask App  │ │  │ │  Flask App  │ │          │
│  │ │  Port: 5002 │ │  │ │  Port: 5002 │ │  │ │  Port: 5002 │ │          │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │          │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘          │
│                                                                           │
│  • Horizontal Pod Autoscaler (HPA):                                      │
│    - Min: 2 replicas, Max: 10 replicas                                   │
│    - Scale on CPU (70%) and Memory (80%)                                 │
│  • Health Probes: Liveness & Readiness on /health                        │
│  • Resources: 250m-1000m CPU, 512Mi-1Gi Memory                           │
└───────────────┬───────────────────────────────┬───────────────────────────┘
                │                               │
                │ Process requests:             │ Create/manage:
                │ - Health checks              │
                │ - Job creation               ▼
                │ - Job status                ┌────────────────────────────┐
                │ - Index management          │   KUBERNETES JOBS          │
                │                             │  • Parallelism: 1-N        │
                ▼                             │  • Completions: 1          │
┌───────────────────────────────────────────┐ │  • Backoff Limit: 5        │
│      AZURE BACKEND SERVICES               │ │  • Active Deadline: 3600s  │
│  ┌──────────────────────────────────────┐ │ │  • Service Account: RBAC   │
│  │  Azure Blob Storage                  │ │ └────────────────────────────┘
│  │  • Document storage                  │ │
│  │  • PDF files                         │ │
│  │  Connection via SDK                  │ │
│  └──────────────────────────────────────┘ │
│  ┌──────────────────────────────────────┐ │
│  │  Azure Cognitive Search              │ │
│  │  • Vector search                     │ │
│  │  • Index management                  │ │
│  │  • Full-text search                  │ │
│  └──────────────────────────────────────┘ │
│  ┌──────────────────────────────────────┐ │
│  │  Azure OpenAI Service                │ │
│  │  • Text embedding (text-embedding)   │ │
│  │  • GPT-4 processing                  │ │
│  │  • API Version: 2023-05-15           │ │
│  └──────────────────────────────────────┘ │
└───────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│                          REQUEST FLOW EXAMPLES                            │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  1. HEALTH CHECK REQUEST                                                  │
│     Client → LB → Service → Pod → /health                                │
│     Returns: {"status": "healthy", "service": "bemind-api"}              │
│                                                                           │
│  2. CREATE JOB REQUEST                                                    │
│     Client → LB → Service → Pod → POST /api/jobs                         │
│     Pod authenticates → Creates K8s Job → Returns job details            │
│                                                                           │
│  3. INDEXING JOB EXECUTION                                                │
│     K8s Job Pod → Azure Blob (read PDFs)                                 │
│                → Azure OpenAI (generate embeddings)                      │
│                → Azure Search (index documents)                          │
│                                                                           │
│  4. JOB STATUS REQUEST                                                    │
│     Client → LB → Service → Pod → GET /api/jobs/{name}/status           │
│     Pod queries K8s API → Returns job status & pod metrics               │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

### Key Components

1. **Azure Load Balancer**: Automatically provisioned by AKS when Service type is LoadBalancer
   - Performs health checks every 5 seconds
   - Routes only to healthy pods
   - Provides session affinity for consistent routing

2. **Kubernetes Service**: Acts as a stable endpoint and load balancer
   - Discovers pods using label selectors
   - Maintains connection to healthy pods only
   - Internal load balancing across pod replicas

3. **API Pods**: Stateless Flask applications running with Gunicorn
   - Auto-scaling based on CPU/Memory metrics
   - Each pod can handle multiple concurrent requests
   - Independent processing with no shared state

4. **Kubernetes Jobs**: Dynamically created for indexing tasks
   - Isolated execution environment
   - Configurable parallelism and retry logic
   - Direct access to Azure services via secrets

## 📦 Prerequisites

### Required Software
- Azure CLI (`az`) >= 2.50.0
- kubectl >= 1.27.0
- Bash shell (Git Bash on Windows, native on Linux/Mac)

### Azure Resources (Must exist before deployment)
- Azure Subscription
- Resource Group
- AKS Cluster
- Azure Container Registry (ACR) attached to AKS
- Azure Storage Account
- Azure Cognitive Search Service
- Azure OpenAI Service

### Verify Prerequisites

```bash
# Check Azure CLI
az --version

# Check kubectl
kubectl version --client

# Login to Azure
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

## 🚀 Quick Start

### 1. Clone and Configure

```bash
cd ~/
git clone <your-repo-url> k8s-indexer-deployment
cd k8s-indexer-deployment
```

### 2. Setup Environment

```bash
# Copy and edit environment configuration
cp scripts/bemind-env.sh ~/bemind-env.sh
nano ~/bemind-env.sh  # Edit with your Azure resource names

# Source the environment
source ~/bemind-env.sh
```

### 3. Setup Credentials

**Option A: Interactive (Recommended for first-time setup)**
```bash
bash scripts/create-secrets-existing.sh
```

**Option B: From credentials file**
```bash
# Copy template
cp .bemind-credentials.env.template ~/.bemind-credentials.env

# Edit with your credentials
nano ~/.bemind-credentials.env

# Deploy with credentials
bash scripts/create-secrets-from-env.sh
```

### 4. Deploy

```bash
# Full production deployment
bash scripts/deploy-with-existing-services.sh v1.0.0

# Or deploy API only (faster, for updates)
bash scripts/deploy-api.sh
```

### 5. Verify Deployment

```bash
# Check pod status
kubectl get pods -n bemindindexer -l app=bemind-api

# Check service
kubectl get svc bemind-api-service -n bemindindexer

# View logs
kubectl logs -l app=bemind-api -n bemindindexer --tail=50
```

## 📚 Deployment Guide

### Environment Configuration

Edit [`~/bemind-env.sh`](scripts/bemind-env.sh):

```bash
# Azure Core Settings
export SUBSCRIPTION_ID="your-subscription-id"
export RESOURCE_GROUP="DEV-BeMind"
export LOCATION="swedencentral"

# AKS Configuration
export AKS_CLUSTER_NAME="bemind_aks"
export NAMESPACE="default"

# ACR Configuration
export ACR_NAME="devbemindcontainerregistryse"
export ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

# Azure Services
export STORAGE_ACCOUNT_NAME="avadatastore"
export SEARCH_SERVICE_NAME="be-tt-ava-aisearch-bechtle"
export OPENAI_RESOURCE_NAME="be-tt-ava-openaieu"
```

### Credentials Setup

Required credentials in [`~/.bemind-credentials.env`](.bemind-credentials.env.template):

```bash
# Azure OpenAI
export AZURE_OPENAI_KEY="your-openai-api-key"

# Azure Cognitive Search
export AZURE_SEARCH_KEY="your-search-admin-key"

# Azure Storage
export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;..."

# JWT Secret (auto-generated if not provided)
export JWT_SECRET="your-secure-jwt-secret"
```

### Deployment Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| [`deploy-with-existing-services.sh`](scripts/deploy-with-existing-services.sh) | Full production deployment | `bash scripts/deploy-with-existing-services.sh v1.0.0` |
| [`deploy-api.sh`](scripts/deploy-api.sh) | Deploy API only (fast updates) | `bash scripts/deploy-api.sh` |
| [`build-and-push.sh`](scripts/build-and-push.sh) | Build and push images to ACR | `bash scripts/build-and-push.sh v1.0.1` |
| [`setup-acr.sh`](scripts/setup-acr.sh) | Configure ACR access | `bash scripts/setup-acr.sh` |
| [`create-secrets-existing.sh`](scripts/create-secrets-existing.sh) | Create secrets interactively | `bash scripts/create-secrets-existing.sh` |
| [`create-secrets-from-env.sh`](scripts/create-secrets-from-env.sh) | Create secrets from file | `bash scripts/create-secrets-from-env.sh` |

### Image Versioning

The build system automatically handles versioning:

```bash
# Build specific version
bash scripts/build-and-push.sh v1.0.1

# Images created:
# - bemind-api:v1.0.1
# - bemind-api:v1.0.1-<timestamp>
# - bemind-api:latest
```

## 🔌 API Reference

### Base URL
```
http://<EXTERNAL_IP>:5002
```

Get external IP:
```bash
# First, ensure kubectl is connected to your AKS cluster
az aks get-credentials --resource-group YOUR_RESOURCE_GROUP --name YOUR_AKS_CLUSTER --overwrite-existing

# Then get the external IP (LoadBalancer is internet-accessible by default)
kubectl get svc bemind-api-service -n bemindindexer -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**Note:** The Azure Load Balancer created by the LoadBalancer service is configured to accept traffic from anywhere on the internet (0.0.0.0/0). No additional firewall rules or network security groups are required for basic internet access.

### Health Endpoints

#### Health Check
```bash
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "bemind-api"
}
```

#### Readiness Check
```bash
GET /readiness
```

### Job Management Endpoints

#### Create Job
```bash
POST /api/jobs
Content-Type: application/json

{
  "job_name": "my-indexing-job",
  "parallelism": 3,
  "completions": 1,
  "backoff_limit": 5,
  "active_deadline_seconds": 3600,
  "replace_existing": false,
  "job_type": "indexing",
  "env": {
    "INDEX_NAME": "my-index",
    "BATCH_SIZE": "100"
  }
}
```

**Parameters:**
- `job_name` (optional): Custom job name. Auto-generated if not provided.
- `parallelism` (default: 3): Number of parallel pods
- `completions` (default: 1): Number of successful completions needed
- `backoff_limit` (default: 5): Max retry attempts
- `active_deadline_seconds` (default: 3600): Job timeout
- `replace_existing` (default: false): Delete and recreate if job exists
- `job_type`: Label for job categorization
- `env`: Custom environment variables for the job

**Response:**
```json
{
  "message": "Job created successfully",
  "job_name": "indexing-job-1234567890-abc123",
  "namespace": "default",
  "replaced_existing": false,
  "configuration": {
    "parallelism": 3,
    "completions": 1,
    "backoff_limit": 5,
    "active_deadline_seconds": 3600
  },
  "status_url": "/api/jobs/indexing-job-1234567890-abc123/status"
}
```

#### Get Job Status
```bash
GET /api/jobs/{job_name}/status
```

**Response:**
```json
{
  "name": "indexing-job-1234567890-abc123",
  "namespace": "default",
  "status": "Running",
  "created": "2024-01-15T10:30:00Z",
  "start_time": "2024-01-15T10:30:05Z",
  "duration_seconds": 125.5,
  "configuration": {
    "parallelism": 3,
    "completions": 1,
    "backoff_limit": 5
  },
  "metrics": {
    "succeeded": 0,
    "active": 3,
    "failed": 0,
    "ready": 2,
    "total_pods": 3
  },
  "pods": [
    {
      "name": "indexing-job-abc123-pod1",
      "phase": "Running",
      "start_time": "2024-01-15T10:30:05Z",
      "restarts": 0,
      "node": "aks-nodepool1-12345678-vmss000000"
    }
  ]
}
```

#### List Jobs
```bash
GET /api/jobs?status=running&job_type=indexing
```

**Query Parameters:**
- `status`: Filter by status (Running, Completed, Failed, Pending)
- `job_type`: Filter by job type label

**Response:**
```json
{
  "jobs": [
    {
      "name": "indexing-job-1234567890-abc123",
      "status": "Running",
      "created": "2024-01-15T10:30:00Z",
      "configuration": {
        "parallelism": 3,
        "completions": 1
      },
      "metrics": {
        "succeeded": 0,
        "active": 3,
        "failed": 0
      }
    }
  ],
  "total": 1,
  "filters": {
    "status": "running",
    "job_type": "indexing"
  }
}
```

#### Delete Job
```bash
DELETE /api/jobs/{job_name}
```

**Response:**
```json
{
  "message": "Job deleted successfully",
  "job_name": "indexing-job-1234567890-abc123"
}
```

### Index Management Endpoints

#### Create Index
```bash
POST /api/indices
Content-Type: application/json

{
  "index_name": "my-index",
  "settings": {}
}
```

#### Get Index
```bash
GET /api/indices/{index_id}
```

#### Update Index
```bash
PUT /api/indices/{index_id}
```

#### Delete Index
```bash
DELETE /api/indices/{index_id}
```

## 🧪 Testing

### Automated Test Suite

Run the complete test suite:

```bash
# Run all tests
bash scripts/test-suite.sh

# Run specific test
bash scripts/test-deployment.sh      # Deployment health
bash scripts/test-api-endpoints.sh   # API functionality
bash scripts/test-job-parallelism.sh # Job management
bash scripts/test-autoscaling.sh     # HPA testing
```

See the [Testing Guide](#complete-test-example) below for detailed test scenarios.

### Manual Testing

#### Test Health Endpoint
```bash
EXTERNAL_IP=$(kubectl get svc bemind-api-service -n bemindindexer -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://${EXTERNAL_IP}:5002/health
```

#### Test Job Creation
```bash
curl -X POST http://${EXTERNAL_IP}:5002/api/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "parallelism": 2,
    "completions": 1,
    "job_type": "test"
  }'
```

#### Port Forward for Local Testing
```bash
kubectl port-forward svc/bemind-api-service 8080:5002 -n bemindindexer

# Test locally
curl http://localhost:8080/health
```

### Complete Test Example

See [`scripts/test-suite.sh`](scripts/test-suite.sh) for a comprehensive test that validates:

1. ✅ Pod status and readiness
2. ✅ Deployment replica count
3. ✅ Service endpoints
4. ✅ Health check responses
5. ✅ ConfigMap and Secret existence
6. ✅ Job creation and management
7. ✅ Autoscaling configuration
8. ✅ Resource usage metrics
9. ✅ Error handling
10. ✅ API functionality

**Example output:**
```
========================================
BeMind Complete Test Suite
========================================

Test 1: Deployment Health...
✓ All pods running (2/2)
✓ Deployment ready (2/2 replicas)

Test 2: API Health Check...
✓ Health endpoint responding

Test 3: Job Creation...
✓ Job created successfully
✓ Job status retrievable

Test 4: Autoscaling...
✓ HPA configured (2-10 replicas)

All Tests Passed! ✓
```

## 📊 Monitoring & Troubleshooting

### View Logs

```bash
# All API pods
kubectl logs -l app=bemind-api -n bemindindexer --tail=100 --follow

# Specific pod
kubectl logs <pod-name> -n bemindindexer

# Previous pod instance (if crashed)
kubectl logs <pod-name> -n bemindindexer --previous
```

### Check Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n bemindindexer -l app=bemind-api

# HPA status
kubectl get hpa -n bemindindexer --watch
```

### Debugging

```bash
# Describe pod for events
kubectl describe pod <pod-name> -n bemindindexer

# Describe deployment
kubectl describe deployment bemind-api -n bemindindexer

# Check secrets
kubectl get secrets -n bemindindexer
kubectl describe secret bemind-secrets -n bemindindexer

# Execute into pod
kubectl exec -it <pod-name> -n bemindindexer -- /bin/bash
```

### Common Issues

#### Pods not starting
```bash
# Check events
kubectl get events -n bemindindexer --sort-by='.lastTimestamp'

# Check image pull
kubectl describe pod <pod-name> -n bemindindexer | grep -A 10 "Events:"
```

#### Service not accessible
```bash
# Check service endpoints
kubectl get endpoints bemind-api-service -n bemindindexer

# Check load balancer
kubectl get svc bemind-api-service -n bemindindexer

# Check network policies
kubectl get networkpolicies -n bemindindexer
```

#### Job failures
```bash
# List jobs
kubectl get jobs -n bemindindexer

# Check job status
kubectl describe job <job-name> -n bemindindexer

# View pod logs
kubectl logs -l job-name=<job-name> -n bemindindexer
```

## 🗑️ Cleanup

### Remove Deployment (Keep Azure Resources)

```bash
# Clean up all Kubernetes resources
bash scripts/cleanup.sh
```

This removes:
- Deployments
- Services
- HPA
- ConfigMaps
- Secrets
- ServiceAccounts
- RBAC resources

### Complete Cleanup (Including Tracked Resources)

```bash
# Clean up everything deployed by deploy-with-existing-services.sh
bash scripts/cleanup-deployment.sh
```

This removes all tracked resources including:
- All Kubernetes resources
- Optionally: Container images from ACR
- Tracking metadata

### Manual Cleanup

```bash
# Delete specific resources
kubectl delete deployment bemind-api -n bemindindexer
kubectl delete service bemind-api-service -n bemindindexer
kubectl delete hpa bemind-api-hpa -n bemindindexer
kubectl delete configmap bemind-config -n bemindindexer
kubectl delete secret bemind-secrets -n bemindindexer

# Delete namespace (removes everything)
kubectl delete namespace default  # Be careful with default namespace!
```

## 📁 Project Structure

```
k8s-indexer-deployment/
├── README.md                          # This file
├── requirements.txt                   # Python dependencies
├── .dockerignore                      # Docker build exclusions
├── Dockerfile.api                     # API container image
├── Dockerfile.indexer                 # Indexer container image
├── .bemind-credentials.env.template   # Credentials template
│
├── src/
│   ├── api/                          # Flask API application
│   │   ├── __init__.py
│   │   ├── app.py                    # Main Flask app
│   │   └── routes/
│   │       ├── __init__.py
│   │       ├── health.py             # Health endpoints
│   │       ├── indices.py            # Index management
│   │       └── jobs.py               # Job management
│   │
│   ├── indexer/                      # Indexing job logic
│   │   ├── __init__.py
│   │   ├── job.py                    # Job execution
│   │   └── processors/
│   │       ├── __init__.py
│   │       ├── blob_handler.py       # Azure Blob operations
│   │       ├── pdf_converter.py      # PDF processing
│   │       └── search_indexer.py     # Search indexing
│   │
│   └── utils/                        # Shared utilities
│       ├── __init__.py
│       ├── auth.py                   # Authentication
│       └── logger.py                 # Logging setup
│
├── k8s/                              # Kubernetes manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── rbac.yaml
│   ├── serviceaccount.yaml
│   ├── api-deployment.yaml           # Main API deployment
│   ├── api-service.yaml
│   ├── api-service-loadbalancer.yaml
│   └── indexer-cronjob.yaml
│
└── scripts/                          # Deployment scripts
    ├── bemind-env.sh                 # Environment configuration
    ├── deploy-with-existing-services.sh  # Full deployment
    ├── deploy-api.sh                 # API-only deployment
    ├── deploy-production.sh          # Production deployment
    ├── build-and-push.sh             # Build images
    ├── setup-acr.sh                  # ACR setup
    ├── create-secrets-existing.sh    # Interactive secrets
    ├── create-secrets-from-env.sh    # File-based secrets
    ├── cleanup.sh                    # Remove deployment
    ├── cleanup-deployment.sh         # Complete cleanup
    ├── test-suite.sh                 # Complete test suite
    ├── test-deployment.sh            # Deployment tests
    ├── test-api-endpoints.sh         # API tests
    ├── test-job-parallelism.sh       # Job tests
    └── test-autoscaling.sh           # HPA tests
```

## 🔐 Security Best Practices

1. **Secrets Management**
   - Never commit credentials to Git
   - Use Kubernetes secrets for sensitive data
   - Rotate secrets regularly
   - Use Azure Key Vault integration (future enhancement)

2. **RBAC**
   - Minimal permissions for service accounts
   - Separate accounts for API and Jobs
   - Regular audit of permissions

3. **Network Security**
   - Use Network Policies (future enhancement)
   - Restrict egress traffic
   - Use Private Endpoints for Azure services (future enhancement)

4. **Container Security**
   - Run as non-root user
   - Read-only root filesystem where possible
   - Regular image scanning
   - Multi-stage builds to minimize attack surface

## 🚀 Performance Tuning

### Resource Limits

Edit [`k8s/api-deployment.yaml`](k8s/api-deployment.yaml):

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

### Autoscaling

Adjust HPA settings in [`k8s/api-deployment.yaml`](k8s/api-deployment.yaml):

```yaml
minReplicas: 2
maxReplicas: 10
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Job Parallelism

Optimize job performance:

```json
{
  "parallelism": 5,        // More parallel workers
  "completions": 1,        // Single completion
  "cpu_request": "1000m",  // More CPU
  "memory_request": "2Gi"  // More memory
}
```

## 📞 Support & Contribution

### Getting Help

1. Check the [Troubleshooting](#monitoring--troubleshooting) section
2. Review logs: `kubectl logs -l app=bemind-api -n bemindindexer --tail=100`
3. Check Azure Portal for service health
4. Review Kubernetes events: `kubectl get events -n bemindindexer --sort-by='.lastTimestamp'`

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly using [`scripts/test-suite.sh`](scripts/test-suite.sh)
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Azure Kubernetes Service team
- Kubernetes community
- Flask framework
- OpenAI and Azure Cognitive Services teams

---

**Version:** 1.0.0  
**Last Updated:** 2024-01-15  
**Maintained by:** BeMind Team
