#!/bin/bash

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

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              BeMind Cleanup Script                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"

echo ""
echo "⚠️  WARNING: This will delete all BeMind resources from AKS"
echo ""
echo "Resources to be deleted:"
echo "  - Namespace: $NAMESPACE"
echo "  - All deployments, services, pods in namespace"
echo "  - All secrets and configmaps in namespace"
echo "  - All jobs in namespace"
echo ""

read -p "Are you sure? Type 'DELETE' to confirm: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Connecting to AKS..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

echo ""
echo "Deleting namespace and all resources..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found=true --timeout=300s

echo ""
echo "✓ Cleanup completed"
echo ""
echo "To redeploy:"
echo "  bash $SCRIPT_DIR/deploy-production.sh v1.0.0"