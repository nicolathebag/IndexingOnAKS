#!/bin/bash
# ================================================================
# BeMind API Deployment Script (No Docker Required)
# Deploys directly to AKS - assumes ACR integration is configured
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
echo -e "${GREEN}BeMind API Deployment to AKS${NC}"
echo -e "${GREEN}========================================${NC}"

# Validate required environment variables
if [[ -z "$SUBSCRIPTION_ID" ]]; then
    echo -e "${RED}Error: SUBSCRIPTION_ID not set${NC}"
    exit 1
fi

# Step 1: Login to Azure (if not already logged in)
echo -e "${YELLOW}Step 1: Checking Azure login...${NC}"
az account show > /dev/null 2>&1 || az login

# Step 2: Get AKS credentials
echo -e "${YELLOW}Step 2: Getting AKS credentials...${NC}"
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

# Step 3: Verify ACR access from AKS
echo -e "${YELLOW}Step 3: Verifying ACR integration with AKS...${NC}"
ACR_ID=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
echo -e "${GREEN}✓ ACR found: $ACR_NAME${NC}"

# Step 4: Attach ACR to AKS (if not already attached)
echo -e "${YELLOW}Step 4: Ensuring AKS can pull from ACR...${NC}"
az aks update \
    --name "$AKS_CLUSTER_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --attach-acr "$ACR_NAME" 2>/dev/null || echo "ACR already attached"

# Step 5: Verify image exists in ACR
echo -e "${YELLOW}Step 5: Verifying image exists in ACR...${NC}"
IMAGE_EXISTS=$(az acr repository show \
    --name "$ACR_NAME" \
    --image "bemind-api:${CURRENT_VERSION}" \
    --query "name" -o tsv 2>/dev/null || echo "")

if [[ -z "$IMAGE_EXISTS" ]]; then
    echo -e "${RED}Warning: Image bemind-api:${CURRENT_VERSION} not found in ACR${NC}"
    echo -e "${YELLOW}Available images:${NC}"
    az acr repository list --name "$ACR_NAME" -o table
    echo -e "${YELLOW}Please build and push the image first, or update CURRENT_VERSION in bemind-env.sh${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ Image found: bemind-api:${CURRENT_VERSION}${NC}"
fi

# Step 6: Create namespace if it doesn't exist
echo -e "${YELLOW}Step 6: Creating namespace...${NC}"
kubectl apply -f ../k8s/namespace.yaml

# Step 7: Create/Update secrets
echo -e "${YELLOW}Step 7: Applying secrets...${NC}"
kubectl apply -f ../k8s/secrets.yaml

# Step 8: Apply ConfigMap
echo -e "${YELLOW}Step 8: Applying ConfigMap...${NC}"
kubectl apply -f ../k8s/configmap.yaml

# Step 9: Apply RBAC
echo -e "${YELLOW}Step 9: Applying RBAC...${NC}"
kubectl apply -f ../k8s/rbac.yaml
kubectl apply -f ../k8s/serviceaccount.yaml

# Step 10: Deploy API
echo -e "${YELLOW}Step 10: Deploying API...${NC}"
kubectl apply -f ../k8s/api-deployment.yaml

# Step 11: Wait for rollout
echo -e "${YELLOW}Step 11: Waiting for deployment to complete...${NC}"
kubectl rollout status deployment/bemind-api -n bemindindexer --timeout=5m

# Step 12: Check deployment status
echo -e "${YELLOW}Step 12: Checking deployment status...${NC}"
echo -e "${GREEN}Pods:${NC}"
kubectl get pods -n bemindindexer -l app=bemind-api

echo -e "${GREEN}Service:${NC}"
kubectl get svc -n bemindindexer -l app=bemind-api

echo -e "${GREEN}HPA:${NC}"
kubectl get hpa -n bemindindexer

# Step 13: Get pod logs (last 10 lines)
echo -e "${YELLOW}Step 13: Recent pod logs:${NC}"
POD_NAME=$(kubectl get pods -n bemindindexer -l app=bemind-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$POD_NAME" ]]; then
    kubectl logs "$POD_NAME" -n bemindindexer --tail=10 || echo "No logs available yet"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"

# Get service endpoint
SERVICE_IP=$(kubectl get svc bemind-api-service -n bemindindexer -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending...")
if [[ "$SERVICE_IP" != "Pending..." ]]; then
    echo -e "${GREEN}API Service Endpoint: http://${SERVICE_IP}:5002${NC}"
else
    echo -e "${YELLOW}Service IP is still pending. Run this to check later:${NC}"
    echo -e "${YELLOW}kubectl get svc bemind-api-service -n bemindindexer${NC}"
fi