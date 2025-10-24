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
az account set --subscription "$SUBSCRIPTION_ID"

# Step 2: Get AKS credentials
echo -e "${YELLOW}Step 2: Getting AKS credentials...${NC}"
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

# Step 3: Verify image exists in ACR
echo -e "${YELLOW}Step 3: Verifying image exists in ACR...${NC}"
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

# Step 4: Create/Update secrets (using default namespace)
echo -e "${YELLOW}Step 4: Applying secrets...${NC}"
kubectl apply -f ../k8s/secrets.yaml

# Step 5: Apply ConfigMap
echo -e "${YELLOW}Step 5: Applying ConfigMap...${NC}"
kubectl apply -f ../k8s/configmap.yaml

# Step 6: Apply RBAC
echo -e "${YELLOW}Step 6: Applying RBAC...${NC}"
kubectl apply -f ../k8s/rbac.yaml
kubectl apply -f ../k8s/serviceaccount.yaml

# Step 7: Deploy API
echo -e "${YELLOW}Step 7: Deploying API...${NC}"
kubectl apply -f ../k8s/api-deployment.yaml

# Step 8: Wait for rollout
echo -e "${YELLOW}Step 8: Waiting for deployment to complete...${NC}"
kubectl rollout status deployment/bemind-api -n default --timeout=5m

# Step 9: Check deployment status
echo -e "${YELLOW}Step 9: Checking deployment status...${NC}"
echo -e "${GREEN}Pods:${NC}"
kubectl get pods -n default -l app=bemind-api

echo -e "${GREEN}Service:${NC}"
kubectl get svc -n default -l app=bemind-api

echo -e "${GREEN}HPA:${NC}"
kubectl get hpa -n default

# Step 10: Get pod logs (last 10 lines)
echo -e "${YELLOW}Step 10: Recent pod logs:${NC}"
POD_NAME=$(kubectl get pods -n default -l app=bemind-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$POD_NAME" ]]; then
    kubectl logs "$POD_NAME" -n default --tail=10 || echo "No logs available yet"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"

# Save deployed resources to tracking file
TRACKING_FILE="${SCRIPT_DIR}/.bemind-resources.txt"
echo "# BeMind Deployed Resources - $(date)" > "$TRACKING_FILE"
echo "namespace=default" >> "$TRACKING_FILE"
echo "deployment=bemind-api" >> "$TRACKING_FILE"
echo "service=bemind-api-service" >> "$TRACKING_FILE"
echo "hpa=bemind-api-hpa" >> "$TRACKING_FILE"
echo "configmap=bemind-app-config" >> "$TRACKING_FILE"
echo "secret=my-secret" >> "$TRACKING_FILE"
echo "serviceaccount=bemind-indexer-sa,bemind-worker" >> "$TRACKING_FILE"
echo "role=bemind-indexer-role" >> "$TRACKING_FILE"
echo "rolebinding=bemind-indexer-rolebinding" >> "$TRACKING_FILE"

echo -e "${GREEN}✓ Resource tracking saved to: $TRACKING_FILE${NC}"
echo ""

# Get service endpoint
SERVICE_IP=$(kubectl get svc bemind-api-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending...")
if [[ "$SERVICE_IP" != "Pending..." ]]; then
    echo -e "${GREEN}API Service Endpoint: http://${SERVICE_IP}:5002${NC}"
else
    echo -e "${YELLOW}Service IP is still pending. Run this to check later:${NC}"
    echo -e "${YELLOW}kubectl get svc bemind-api-service -n default${NC}"
fi

echo ""
echo -e "${YELLOW}To clean up all resources, run:${NC}"
echo -e "${YELLOW}  ./scripts/cleanup.sh${NC}"