#!/bin/bash
# ================================================================
# BeMind API Deployment Script
# Pulls images from ACR, then deploys to AKS
# ================================================================

set -e  # Exit on error

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/bemind-env.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}BeMind API Deployment${NC}"
echo -e "${GREEN}========================================${NC}"

# Validate required environment variables
if [[ -z "$SUBSCRIPTION_ID" ]]; then
    echo -e "${RED}Error: SUBSCRIPTION_ID not set${NC}"
    exit 1
fi

# Step 1: Login to Azure (if not already logged in)
echo -e "${YELLOW}Step 1: Checking Azure login...${NC}"
az account show > /dev/null 2>&1 || az login
az account set --subscription "$SUBSCRIPTION_ID"

# Step 2: Get AKS credentials
echo -e "${YELLOW}Step 2: Getting AKS credentials...${NC}"
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

# Step 3: Login to ACR
echo -e "${YELLOW}Step 3: Logging into ACR...${NC}"
az acr login --name "$ACR_NAME"

# Step 4: Pull latest images
echo -e "${YELLOW}Step 4: Pulling latest images from ACR...${NC}"
docker pull "${ACR_LOGIN_SERVER}/bemind-api:${CURRENT_VERSION}"
docker pull "${ACR_LOGIN_SERVER}/bemind-api:latest"

echo -e "${GREEN}✓ Images pulled successfully${NC}"

# Step 5: Create namespace if it doesn't exist
echo -e "${YELLOW}Step 5: Creating namespace...${NC}"
kubectl apply -f ../k8s/namespace.yaml

# Step 6: Create secrets (if they don't exist)
echo -e "${YELLOW}Step 6: Checking secrets...${NC}"
if ! kubectl get secret bemind-secrets -n bemindindexer > /dev/null 2>&1; then
    echo -e "${YELLOW}Creating secrets...${NC}"
    kubectl apply -f ../k8s/secrets.yaml
else
    echo -e "${GREEN}✓ Secrets already exist${NC}"
fi

# Step 7: Apply ConfigMap
echo -e "${YELLOW}Step 7: Applying ConfigMap...${NC}"
kubectl apply -f ../k8s/configmap.yaml

# Step 8: Apply RBAC
echo -e "${YELLOW}Step 8: Applying RBAC...${NC}"
kubectl apply -f ../k8s/rbac.yaml
kubectl apply -f ../k8s/serviceaccount.yaml

# Step 9: Deploy API
echo -e "${YELLOW}Step 9: Deploying API...${NC}"
kubectl apply -f ../k8s/api-deployment.yaml

# Step 10: Wait for rollout
echo -e "${YELLOW}Step 10: Waiting for deployment to complete...${NC}"
kubectl rollout status deployment/bemind-api -n bemindindexer --timeout=5m

# Step 11: Check deployment status
echo -e "${YELLOW}Step 11: Checking deployment status...${NC}"
kubectl get pods -n bemindindexer -l app=bemind-api
kubectl get svc -n bemindindexer -l app=bemind-api
kubectl get hpa -n bemindindexer

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"

# Get service endpoint
SERVICE_IP=$(kubectl get svc bemind-api-service -n bemindindexer -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending...")
echo -e "${GREEN}API Service Endpoint: http://${SERVICE_IP}:5002${NC}"