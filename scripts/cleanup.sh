#!/bin/bash
# ================================================================
# Cleanup Script
# Deletes all tracked resources from default namespace
# ================================================================

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source environment
if [ -f "$HOME/env.sh" ]; then
    source "$HOME/env.sh"
elif [ -f "$SCRIPT_DIR/env.sh" ]; then
    source "$SCRIPT_DIR/env.sh"
else
    echo "Error: env.sh not found"
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║              Cleanup Script                            ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${YELLOW}⚠️  WARNING: This will delete all resources from default namespace${NC}"
echo ""
echo "Resources to be deleted:"
echo "  - Deployment: indexer-api"
echo "  - Service: indexer-api-service"
echo "  - HorizontalPodAutoscaler: indexer-api-hpa"
echo "  - ConfigMap: indexer-app-config"
echo "  - Secret: my-secret"
echo "  - ServiceAccount: indexer-sa, indexer-worker"
echo "  - Role: indexer-role"
echo "  - RoleBinding: indexer-rolebinding"
echo ""

read -p "Are you sure? Type 'DELETE' to confirm: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo -e "${GREEN}Cleanup cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Connecting to AKS...${NC}"
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

echo ""
echo -e "${YELLOW}Deleting resources from default namespace...${NC}"

# Delete HPA
echo -e "${YELLOW}Deleting HorizontalPodAutoscaler...${NC}"
kubectl delete hpa indexer-api-hpa -n indexer --ignore-not-found=true

# Delete Deployment
echo -e "${YELLOW}Deleting Deployment...${NC}"
kubectl delete deployment indexer-api -n indexer --ignore-not-found=true

# Delete Service
echo -e "${YELLOW}Deleting Services...${NC}"
kubectl delete service indexer-api-service -n indexer --ignore-not-found=true
kubectl delete service api-service -n indexer --ignore-not-found=true

# Delete ConfigMap
echo -e "${YELLOW}Deleting ConfigMaps...${NC}"
kubectl delete configmap indexer-app-config -n indexer --ignore-not-found=true

# Delete Secret
echo -e "${YELLOW}Deleting Secrets...${NC}"
kubectl delete secret my-secret -n indexer --ignore-not-found=true

# Delete RBAC resources
echo -e "${YELLOW}Deleting RBAC resources...${NC}"
kubectl delete rolebinding indexer-rolebinding -n indexer --ignore-not-found=true
kubectl delete role indexer-role -n indexer --ignore-not-found=true
kubectl delete serviceaccount indexer-sa -n indexer --ignore-not-found=true
kubectl delete serviceaccount indexer-worker -n indexer --ignore-not-found=true

echo ""
echo -e "${GREEN}✓ All resources deleted successfully!${NC}"
echo ""
echo "✓ Cleanup completed"
echo ""
echo "To redeploy:"
echo "  bash $SCRIPT_DIR/deploy-production.sh v1.0.0"
