#!/bin/bash

set -e

# ================================================================
# Deploy Only Script (Skips Secrets Creation)
# Assumes secrets already exist in the cluster
# ================================================================

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

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
echo "║           Deploy Only (Skips Secrets Creation)                ║"
echo "╚════════════════════════════════════════════════════════════════╝"

cd "$PROJECT_ROOT"

# Step 1: Connect to AKS
echo ""
echo "Step 1/5: Connecting to AKS cluster 'bemind_aks'..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "bemind_aks" \
    --overwrite-existing

kubectl cluster-info
echo "✓ Connected to AKS cluster 'bemind_aks'"

# Step 2: Create namespace
echo ""
echo "Step 2/5: Creating namespace..."
kubectl apply -f "$PROJECT_ROOT/k8s/namespace.yaml"
echo "✓ Namespace created"

# Step 3: Verify secrets exist (but don't create them)
echo ""
echo "Step 3/5: Verifying secrets exist..."
if ! kubectl get secret bemind-secrets -n bemindindexer >/dev/null 2>&1; then
    echo "❌ Error: bemind-secrets not found in bemindindexer namespace"
    echo "   Please create secrets first using:"
    echo "   bash scripts/create-secrets-existing.sh"
    echo "   or configure ~/.bemind-credentials.env and run:"
    echo "   bash scripts/create-secrets-from-env.sh"
    exit 1
fi
echo "✓ Secrets verified"

# Step 4: Apply configurations
echo ""
echo "Step 4/5: Applying configurations..."
kubectl apply -f "$PROJECT_ROOT/k8s/configmap.yaml" -n bemindindexer
kubectl apply -f "$PROJECT_ROOT/k8s/rbac.yaml" -n bemindindexer
echo "✓ Configurations applied"

# Step 5: Deploy applications
echo ""
echo "Step 5/5: Deploying applications..."
kubectl apply -f "$PROJECT_ROOT/k8s/api-deployment.yaml" -n bemindindexer

echo "Waiting for API deployment to be ready..."
kubectl rollout status deployment/bemind-api -n bemindindexer --timeout=300s

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Deployment Status:"
echo "════════════════════════════════════════════════════════════════"
kubectl get all -n bemindindexer

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Image Versions Deployed:"
echo "════════════════════════════════════════════════════════════════"
kubectl get deployment bemind-api -n bemindindexer \
    -o jsonpath='{.spec.template.spec.containers[0].image}' | xargs echo "API:"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Resource Usage:"
echo "════════════════════════════════════════════════════════════════"
kubectl top nodes 2>/dev/null || echo "Metrics not available yet"
kubectl top pods -n bemindindexer 2>/dev/null || echo "Metrics not available yet"

echo ""
echo "✓ Deployment completed successfully!"
echo ""
echo "Next steps:"
echo "  1. Verify deployment: kubectl get pods -n bemindindexer"
echo "  2. View logs: kubectl logs -l app=bemind-api -n bemindindexer"
echo "  3. Get external IP: kubectl get svc bemind-api-service -n bemindindexer"
echo "  4. Test API: curl http://<EXTERNAL_IP>/health"