#!/bin/bash

set -e

# Suppress debconf warnings in non-interactive environments
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

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
echo "║   Indexing Deployment with Existing Azure Services              ║"
echo "╚════════════════════════════════════════════════════════════════╝"

cd "$PROJECT_ROOT"

VERSION="${1:-v1.0.0}"
SECRET_MODE="${2:-auto}"

# Initialize resource tracking file
TRACKING_FILE="$SCRIPT_DIR/.deployed-resources.txt"
echo "# Indexing Deployed Resources - $(date)" > "$TRACKING_FILE"
echo "# Deployment Version: $VERSION" >> "$TRACKING_FILE"
echo "# Secret Mode: $SECRET_MODE" >> "$TRACKING_FILE"
echo "" >> "$TRACKING_FILE"

# Auto-detect secret creation method
if [ "$SECRET_MODE" = "auto" ]; then
    if [ -f "$HOME/.credentials.env" ]; then
        SECRET_MODE="--from-file"
        echo "ℹ  Using credentials from ~/.credentials.env"
    else
        SECRET_MODE="--interactive"
        echo "ℹ  Using interactive credential input"
    fi
fi

echo "  Version:   $VERSION"
echo "  Method:    $SECRET_MODE"
echo ""

# Step 1: Setup ACR
echo "Step 1/6: Setting up ACR..."
bash "$SCRIPT_DIR/setup-acr.sh"

# Track ACR
echo "# Azure Container Registry" >> "$TRACKING_FILE"
echo "acr_name=$ACR_NAME" >> "$TRACKING_FILE"
echo "acr_resource_group=$RESOURCE_GROUP" >> "$TRACKING_FILE"
echo "" >> "$TRACKING_FILE"

# Reload environment
if [ -f "$HOME/env.sh" ]; then
    source "$HOME/env.sh"
fi

# Step 2: Build and push images (skips if exist)
echo ""
echo "Step 2/6: Building and pushing images (if needed)..."
bash "$SCRIPT_DIR/build-and-push.sh" "$VERSION"

# Track images
echo "# Container Images" >> "$TRACKING_FILE"
echo "image=${ACR_LOGIN_SERVER}/indexer-api:${VERSION}" >> "$TRACKING_FILE"
echo "image=${ACR_LOGIN_SERVER}/indexer-api:latest" >> "$TRACKING_FILE"
echo "" >> "$TRACKING_FILE"

# Step 3: Connect to AKS
echo ""
echo "Step 3/6: Connecting to AKS..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

# Track AKS
echo "# Azure Kubernetes Service" >> "$TRACKING_FILE"
echo "aks_cluster=$AKS_CLUSTER_NAME" >> "$TRACKING_FILE"
echo "aks_resource_group=$RESOURCE_GROUP" >> "$TRACKING_FILE"
echo "" >> "$TRACKING_FILE"

# Step 4: Create namespace
echo ""
echo "Step 4/6: Creating namespace..."
kubectl apply -f "$PROJECT_ROOT/k8s/namespace.yaml"

# Track namespace
echo "# Kubernetes Namespace" >> "$TRACKING_FILE"
echo "namespace=$NAMESPACE" >> "$TRACKING_FILE"
echo "" >> "$TRACKING_FILE"

# Step 5: Create secrets
echo ""
echo "Step 5/6: Creating secrets ($SECRET_MODE)..."

case "$SECRET_MODE" in
    --interactive)
        bash "$SCRIPT_DIR/create-secrets-existing.sh"
        ;;
    --from-file)
        bash "$SCRIPT_DIR/create-secrets-from-env.sh"
        ;;
    *)
        echo "Error: Invalid secret mode: $SECRET_MODE"
        exit 1
        ;;
esac

# Track secrets
echo "# Kubernetes Secrets" >> "$TRACKING_FILE"
SECRETS=$(kubectl get secrets -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
for secret in $SECRETS; do
    if [[ "$secret" == *"indexer"* ]]; then
        echo "secret=$secret" >> "$TRACKING_FILE"
    fi
done
echo "" >> "$TRACKING_FILE"

# Step 6: Deploy application
echo ""
echo "Step 6/6: Deploying application..."
kubectl apply -f "$PROJECT_ROOT/k8s/configmap.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/rbac.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/api-deployment.yaml"

# Track Kubernetes resources
echo "# Kubernetes Resources" >> "$TRACKING_FILE"
echo "deployment=indexer-api" >> "$TRACKING_FILE"
echo "service=indexer-api-service" >> "$TRACKING_FILE"
echo "hpa=indexer-api-hpa" >> "$TRACKING_FILE"

# Track ConfigMap
CONFIGMAPS=$(kubectl get configmaps -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
for cm in $CONFIGMAPS; do
    if [[ "$cm" == *"indexer"* ]]; then
        echo "configmap=$cm" >> "$TRACKING_FILE"
    fi
done

# Track ServiceAccounts
SAS=$(kubectl get serviceaccounts -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
for sa in $SAS; do
    if [[ "$sa" == *"indexer"* ]]; then
        echo "serviceaccount=$sa" >> "$TRACKING_FILE"
    fi
done

# Track Roles
ROLES=$(kubectl get roles -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
for role in $ROLES; do
    if [[ "$role" == *"indexer"* ]]; then
        echo "role=$role" >> "$TRACKING_FILE"
    fi
done

# Track RoleBindings
ROLEBINDINGS=$(kubectl get rolebindings -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
for rb in $ROLEBINDINGS; do
    if [[ "$rb" == *"indexer"* ]]; then
        echo "rolebinding=$rb" >> "$TRACKING_FILE"
    fi
done

echo "" >> "$TRACKING_FILE"

kubectl rollout status deployment/indexer-api -n "$NAMESPACE" --timeout=300s

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Deployment completed successfully!"
echo "════════════════════════════════════════════════════════════════"
kubectl get all -n "$NAMESPACE"

echo ""
echo "✓ Resource tracking saved to: $TRACKING_FILE"
echo ""
echo "Next steps:"
echo "  kubectl port-forward svc/indexer-api-service 8080:5002 -n $NAMESPACE"
echo "  curl http://localhost:8080/health"
echo ""
echo "To clean up all resources, run:"
echo "  $SCRIPT_DIR/cleanup-deployment.sh"
