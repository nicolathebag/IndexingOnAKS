#!/bin/bash
# ================================================================
# BeMind Cleanup Script
# Deletes all tracked resources from default namespace
# ================================================================

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source environment
if [ -f "$HOME/bemind-env.sh" ]; then
    source "$HOME/bemind-env.sh"
elif [ -f "$SCRIPT_DIR/bemind-env.sh" ]; then
    source "$SCRIPT_DIR/bemind-env.sh"
else
    echo "Error: bemind-env.sh not found"
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║              BeMind Cleanup Script                            ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${YELLOW}⚠️  WARNING: This will delete all BeMind resources from default namespace${NC}"
echo ""
echo "Resources to be deleted:"
echo "  - Deployment: bemind-api"
echo "  - Service: bemind-api-service"
echo "  - HorizontalPodAutoscaler: bemind-api-hpa"
echo "  - ConfigMap: bemind-app-config"
echo "  - Secret: my-secret"
echo "  - ServiceAccount: bemind-indexer-sa, bemind-worker"
echo "  - Role: bemind-indexer-role"
echo "  - RoleBinding: bemind-indexer-rolebinding"
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
echo -e "${YELLOW}Deleting BeMind resources from default namespace...${NC}"

# Delete HPA
echo -e "${YELLOW}Deleting HorizontalPodAutoscaler...${NC}"
kubectl delete hpa bemind-api-hpa -n bemindindexer --ignore-not-found=true

# Delete Deployment
echo -e "${YELLOW}Deleting Deployment...${NC}"
kubectl delete deployment bemind-api -n bemindindexer --ignore-not-found=true

# Delete Service
echo -e "${YELLOW}Deleting Services...${NC}"
kubectl delete service bemind-api-service -n bemindindexer --ignore-not-found=true
kubectl delete service api-service -n bemindindexer --ignore-not-found=true

# Delete ConfigMap
echo -e "${YELLOW}Deleting ConfigMaps...${NC}"
kubectl delete configmap bemind-app-config -n bemindindexer --ignore-not-found=true

# Delete Secret
echo -e "${YELLOW}Deleting Secrets...${NC}"
kubectl delete secret my-secret -n bemindindexer --ignore-not-found=true

# Delete RBAC resources
echo -e "${YELLOW}Deleting RBAC resources...${NC}"
kubectl delete rolebinding bemind-indexer-rolebinding -n bemindindexer --ignore-not-found=true
kubectl delete role bemind-indexer-role -n bemindindexer --ignore-not-found=true
kubectl delete serviceaccount bemind-indexer-sa -n bemindindexer --ignore-not-found=true
kubectl delete serviceaccount bemind-worker -n bemindindexer --ignore-not-found=true

echo ""
echo -e "${GREEN}✓ All BeMind resources deleted successfully!${NC}"
echo ""
echo "✓ Cleanup completed"
echo ""
echo "To redeploy:"
echo "  bash $SCRIPT_DIR/deploy-production.sh v1.0.0"
