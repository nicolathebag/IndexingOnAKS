---

## **Phase 4: Complete Production Deployment Script**

````bash
cat > ~/k8s-indexer-deployment/scripts/deploy-production.sh <<'EOF'
#!/bin/bash

set -e

# ================================================================
# BeMind Production Deployment Script
# Full deployment with ACR, versioning, and best practices
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
echo "║       BeMind Production Deployment to AKS                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"

cd "$PROJECT_ROOT"

# Step 1: Setup ACR
echo ""
echo "Step 1/7: Setting up Azure Container Registry..."
bash "$SCRIPT_DIR/setup-acr.sh"

# Reload environment to get ACR_LOGIN_SERVER
if [ -f "$HOME/bemind-env.sh" ]; then
    source "$HOME/bemind-env.sh"
fi

# Step 2: Build and push images
echo ""
echo "Step 2/7: Building and pushing Docker images..."
VERSION="${1:-v1.0.0}"
bash "$SCRIPT_DIR/build-and-push.sh" "$VERSION"

# Step 3: Connect to AKS
echo ""
echo "Step 3/7: Connecting to AKS..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

kubectl cluster-info
echo "✓ Connected to AKS"

# Step 4: Create namespace
echo ""
echo "Step 4/7: Creating namespace..."
kubectl apply -f "$PROJECT_ROOT/k8s/namespace.yaml"
echo "✓ Namespace created"

# Step 5: Create secrets
echo ""
echo "Step 5/7: Creating secrets..."
bash "$SCRIPT_DIR/create-secrets-existing.sh"
echo "✓ Secrets created"

# Step 6: Apply configurations
echo ""
echo "Step 6/7: Applying configurations..."
kubectl apply -f "$PROJECT_ROOT/k8s/configmap.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/rbac.yaml"
echo "✓ Configurations applied"

# Step 7: Deploy applications
echo ""
echo "Step 7/7: Deploying applications..."
kubectl apply -f "$PROJECT_ROOT/k8s/api-deployment.yaml"

echo "Waiting for API deployment to be ready..."
kubectl rollout status deployment/bemind-api -n "$NAMESPACE" --timeout=300s

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Deployment Status:"
echo "════════════════════════════════════════════════════════════════"
kubectl get all -n "$NAMESPACE"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Image Versions Deployed:"
echo "════════════════════════════════════════════════════════════════"
kubectl get deployment bemind-api -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' | xargs echo "API:"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Resource Usage:"
echo "════════════════════════════════════════════════════════════════"
kubectl top nodes 2>/dev/null || echo "Metrics not available yet"
kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "Metrics not available yet"

echo ""
echo "✓ Production deployment completed successfully!"
echo ""
echo "Next steps:"
echo "  1. Verify deployment: kubectl get pods -n $NAMESPACE"
echo "  2. View logs: kubectl logs -l app=bemind-api -n $NAMESPACE"
echo "  3. Test API: kubectl port-forward svc/bemind-api-service 8080:5002 -n $NAMESPACE"
echo "  4. Monitor: kubectl get hpa -n $NAMESPACE --watch"
echo ""
echo "To update deployment:"
echo "  bash $SCRIPT_DIR/build-and-push.sh v1.0.1"
echo "  kubectl set image deployment/bemind-api api=${ACR_LOGIN_SERVER}/bemind-api:v1.0.1 -n $NAMESPACE"
EOF

chmod +x ~/k8s-indexer-deployment/scripts/deploy-production.sh
````
