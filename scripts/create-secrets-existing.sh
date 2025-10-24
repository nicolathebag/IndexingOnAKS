#!/bin/bash

set -e

# ================================================================
# Create Kubernetes Secrets from Existing Azure Services
# This script uses provided credentials instead of fetching them
# ================================================================

source ~/bemind-env.sh

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Creating Secrets from Existing Azure Services             ║"
echo "╚════════════════════════════════════════════════════════════════╝"

# ================================================================
# YOU MUST PROVIDE THESE CREDENTIALS
# ================================================================

# Prompt for Azure Storage credentials
echo ""
echo "=== Azure Storage Credentials ==="
read -p "Storage Account Name [$STORAGE_ACCOUNT_NAME]: " input_storage_name
STORAGE_ACCOUNT_NAME=${input_storage_name:-$STORAGE_ACCOUNT_NAME}

read -p "Storage Account Key (or press Enter to input connection string): " STORAGE_KEY

if [ -z "$STORAGE_KEY" ]; then
    echo "Enter Storage Connection String:"
    read -s STORAGE_CONNECTION_STRING
else
    STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;AccountName=${STORAGE_ACCOUNT_NAME};AccountKey=${STORAGE_KEY};EndpointSuffix=core.windows.net"
fi

# Prompt for Azure Cognitive Search credentials
echo ""
echo "=== Azure Cognitive Search Credentials ==="
read -p "Search Service Endpoint [$SEARCH_ENDPOINT]: " input_search_endpoint
SEARCH_ENDPOINT=${input_search_endpoint:-$SEARCH_ENDPOINT}

echo "Enter Search Admin Key:"
read -s SEARCH_ADMIN_KEY

# Prompt for Azure OpenAI credentials
echo ""
echo "=== Azure OpenAI Credentials ==="
read -p "OpenAI Endpoint [$OPENAI_ENDPOINT]: " input_openai_endpoint
OPENAI_ENDPOINT=${input_openai_endpoint:-$OPENAI_ENDPOINT}

echo "Enter OpenAI API Key:"
read -s OPENAI_API_KEY

read -p "OpenAI Embedding Deployment Name [$OPENAI_EMBEDDING_DEPLOYMENT]: " input_embedding
OPENAI_EMBEDDING_DEPLOYMENT=${input_embedding:-$OPENAI_EMBEDDING_DEPLOYMENT}

# Generate JWT Secret
echo ""
echo "=== Generating JWT Secret ==="
JWT_SECRET=$(openssl rand -base64 32)

# ================================================================
# Connect to AKS
# ================================================================
echo ""
echo "Connecting to AKS..."
az aks get-credentials \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_CLUSTER_NAME \
    --overwrite-existing

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# ================================================================
# Create Kubernetes Secrets
# ================================================================
echo ""
echo "Creating Kubernetes secrets..."

# Azure OpenAI Secret
kubectl create secret generic azure-openai-secret \
    --from-literal=AZURE_OPENAI_ENDPOINT="${OPENAI_ENDPOINT}" \
    --from-literal=AZURE_OPENAI_API_KEY="${OPENAI_API_KEY}" \
    --from-literal=AZURE_OPENAI_API_VERSION="${OPENAI_API_VERSION}" \
    --from-literal=AZURE_OPENAI_EMBEDDING_DEPLOYMENT="${OPENAI_EMBEDDING_DEPLOYMENT}" \
    --from-literal=AZURE_OPENAI_GPT4_DEPLOYMENT="${OPENAI_GPT4_DEPLOYMENT}" \
    -n $NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Azure OpenAI secret created"

# Azure Cognitive Search Secret
kubectl create secret generic azure-search-secret \
    --from-literal=AZURE_SEARCH_ENDPOINT="${SEARCH_ENDPOINT}" \
    --from-literal=AZURE_SEARCH_KEY="${SEARCH_ADMIN_KEY}" \
    --from-literal=AZURE_SEARCH_API_VERSION="${SEARCH_API_VERSION}" \
    -n $NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Azure Search secret created"

# Azure Storage Secret
kubectl create secret generic azure-storage-secret \
    --from-literal=AZURE_STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_NAME}" \
    --from-literal=AZURE_STORAGE_CONNECTION_STRING="${STORAGE_CONNECTION_STRING}" \
    --from-literal=AZURE_STORAGE_ENDPOINT="${STORAGE_ENDPOINT}" \
    -n $NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Azure Storage secret created"

# API Secrets (JWT)
kubectl create secret generic api-secrets \
    --from-literal=JWT_SECRET="${JWT_SECRET}" \
    -n $NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ API secrets created"

# ================================================================
# Verify Secrets
# ================================================================
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Secrets created successfully:"
kubectl get secrets -n $NAMESPACE
echo "════════════════════════════════════════════════════════════════"

echo ""
echo "✓ All secrets created from existing Azure services"
echo ""
echo "IMPORTANT: Save these credentials securely!"
echo "JWT Secret: $JWT_SECRET"