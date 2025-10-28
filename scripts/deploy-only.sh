#!/bin/bash

set -e

# ================================================================
# Deploy with Secrets Creation
# Creates secrets from existing secrets in indexer namespace
# ================================================================

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Source environment
if [ -f "$HOME/env.sh" ]; then
    source "$HOME/env.sh"
elif [ -f "$SCRIPT_DIR/env.sh" ]; then
    source "$SCRIPT_DIR/env.sh"
else
    echo "Error: env.sh not found"
    exit 1
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                Deploy with Secrets Creation                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"

cd "$PROJECT_ROOT"

# Step 1: Connect to AKS
echo ""
echo "Step 1/5: Connecting to AKS cluster 'indexing_aks'..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "indexing_aks" \
    --overwrite-existing

kubectl cluster-info
echo "✓ Connected to AKS cluster 'indexing_aks'"

# Step 2: Create namespace
echo ""
echo "Step 2/5: Creating namespace..."
kubectl apply -f "$PROJECT_ROOT/k8s/namespace.yaml"
echo "✓ Namespace created"

# Step 3: Create secrets from existing ones
echo ""
echo "Step 3/5: Creating secrets from existing secrets in indexer namespace..."
bash "$SCRIPT_DIR/create-indexer-secrets.sh"
echo "✓ Secrets created"

# Step 4: Apply configurations
echo ""
echo "Step 4/5: Applying configurations..."
kubectl apply -f "$PROJECT_ROOT/k8s/configmap.yaml" -n indexer
kubectl apply -f "$PROJECT_ROOT/k8s/rbac.yaml" -n indexer
echo "✓ Configurations applied"

# Step 5: Deploy applications
echo ""
echo "Step 5/5: Deploying applications..."
kubectl apply -f "$PROJECT_ROOT/k8s/api-deployment.yaml" -n indexer

echo "Waiting for API deployment to be ready..."
kubectl rollout status deployment/indexer-api -n indexer --timeout=300s

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Deployment Status:"
echo "════════════════════════════════════════════════════════════════"
kubectl get all -n indexer

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Image Versions Deployed:"
echo "════════════════════════════════════════════════════════════════"
kubectl get deployment indexer-api -n indexer \
    -o jsonpath='{.spec.template.spec.containers[0].image}' | xargs echo "API:"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Resource Usage:"
echo "════════════════════════════════════════════════════════════════"
kubectl top nodes 2>/dev/null || echo "Metrics not available yet"
kubectl top pods -n indexer 2>/dev/null || echo "Metrics not available yet"

echo ""
echo "✓ Deployment completed successfully!"
echo ""
echo "Next steps:"
echo "  1. Verify deployment: kubectl get pods -n indexer"
echo "  2. View logs: kubectl logs -l app=indexer-api -n indexer"
echo "  3. Get external IP: kubectl get svc indexer-api-service -n indexer"
echo "  4. Test API: curl http://<EXTERNAL_IP>/health"