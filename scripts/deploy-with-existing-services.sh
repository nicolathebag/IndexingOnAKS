#!/bin/bash

set -e

source ~/bemind-env.sh

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   BeMind Deployment with Existing Azure Services              ║"
echo "╚════════════════════════════════════════════════════════════════╝"

cd ~/bemind-indexer

VERSION="${1:-v1.0.0}"

# Step 1: Setup ACR
echo ""
echo "Step 1/6: Setting up ACR..."
bash scripts/setup-acr.sh
source ~/bemind-env.sh

# Step 2: Build and push images
echo ""
echo "Step 2/6: Building and pushing images..."
bash scripts/build-and-push.sh $VERSION

# Step 3: Connect to AKS
echo ""
echo "Step 3/6: Connecting to AKS..."
az aks get-credentials \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_CLUSTER_NAME \
    --overwrite-existing

# Step 4: Create namespace
echo ""
echo "Step 4/6: Creating namespace..."
kubectl apply -f k8s/namespace.yaml

# Step 5: Create secrets from existing services
echo ""
echo "Step 5/6: Creating secrets..."
echo "Choose secret creation method:"
echo "  1) Interactive (prompts for credentials)"
echo "  2) From .env file (~/.bemind-credentials.env)"
read -p "Enter choice (1 or 2): " SECRET_METHOD

if [ "$SECRET_METHOD" = "1" ]; then
    bash scripts/create-secrets-existing.sh
else
    bash scripts/create-secrets-from-env.sh
fi

# Step 6: Deploy application
echo ""
echo "Step 6/6: Deploying application..."
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/rbac.yaml
kubectl apply -f k8s/api-deployment.yaml

kubectl rollout status deployment/bemind-api -n $NAMESPACE --timeout=300s

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Deployment completed successfully!"
echo "════════════════════════════════════════════════════════════════"
kubectl get all -n $NAMESPACE

echo ""
echo "Test the deployment:"
echo "  kubectl port-forward svc/bemind-api-service 8080:5002 -n bemind"
echo "  curl http://localhost:8080/health"