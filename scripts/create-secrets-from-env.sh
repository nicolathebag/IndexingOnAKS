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

# ================================================================
# Load credentials from .env file
# ================================================================

ENV_FILE="$HOME/.bemind-credentials.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Creating credentials file: $ENV_FILE"
    cat > "$ENV_FILE" <<'ENVEOF'
# ================================================================
# Azure Service Credentials
# IMPORTANT: Keep this file secure and never commit to git!
# ================================================================

# Azure Storage
AZURE_STORAGE_ACCOUNT_NAME="your_storage_account"
AZURE_STORAGE_KEY="your_storage_key"
# OR use connection string:
# AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;AccountName=..."

# Azure Cognitive Search
AZURE_SEARCH_ENDPOINT="https://your-search-service.search.windows.net"
AZURE_SEARCH_ADMIN_KEY="your_search_admin_key"

# Azure OpenAI
AZURE_OPENAI_ENDPOINT="https://your-openai-resource.openai.azure.com/"
AZURE_OPENAI_API_KEY="your_openai_api_key"
AZURE_OPENAI_EMBEDDING_DEPLOYMENT="text-embedding-ada-002"
AZURE_OPENAI_GPT4_DEPLOYMENT="gpt-4"

# JWT Secret (auto-generated)
JWT_SECRET=""
ENVEOF
    
    chmod 600 "$ENV_FILE"
    echo ""
    echo "Please edit $ENV_FILE with your credentials"
    echo "Then run this script again"
    exit 1
fi

# Load credentials
source "$ENV_FILE"

# Generate JWT secret if not provided
if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(openssl rand -base64 32)
    echo "JWT_SECRET=\"$JWT_SECRET\"" >> "$ENV_FILE"
fi

# Build connection string if only key provided
if [ -z "$AZURE_STORAGE_CONNECTION_STRING" ] && [ -n "$AZURE_STORAGE_KEY" ]; then
    AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;AccountName=${AZURE_STORAGE_ACCOUNT_NAME};AccountKey=${AZURE_STORAGE_KEY};EndpointSuffix=core.windows.net"
fi

# ================================================================
# Connect to AKS and Create Secrets
# ================================================================

echo "Connecting to AKS..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "Creating secrets..."

# Azure OpenAI
kubectl create secret generic azure-openai-secret \
    --from-literal=AZURE_OPENAI_ENDPOINT="${AZURE_OPENAI_ENDPOINT}" \
    --from-literal=AZURE_OPENAI_API_KEY="${AZURE_OPENAI_API_KEY}" \
    --from-literal=AZURE_OPENAI_API_VERSION="${OPENAI_API_VERSION}" \
    --from-literal=AZURE_OPENAI_EMBEDDING_DEPLOYMENT="${AZURE_OPENAI_EMBEDDING_DEPLOYMENT}" \
    --from-literal=AZURE_OPENAI_GPT4_DEPLOYMENT="${AZURE_OPENAI_GPT4_DEPLOYMENT}" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Azure Search
kubectl create secret generic azure-search-secret \
    --from-literal=AZURE_SEARCH_ENDPOINT="${AZURE_SEARCH_ENDPOINT}" \
    --from-literal=AZURE_SEARCH_KEY="${AZURE_SEARCH_ADMIN_KEY}" \
    --from-literal=AZURE_SEARCH_API_VERSION="${SEARCH_API_VERSION}" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Azure Storage
kubectl create secret generic azure-storage-secret \
    --from-literal=AZURE_STORAGE_ACCOUNT_NAME="${AZURE_STORAGE_ACCOUNT_NAME}" \
    --from-literal=AZURE_STORAGE_CONNECTION_STRING="${AZURE_STORAGE_CONNECTION_STRING}" \
    --from-literal=AZURE_STORAGE_ENDPOINT="https://${AZURE_STORAGE_ACCOUNT_NAME}.blob.core.windows.net" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# API secrets
kubectl create secret generic api-secrets \
    --from-literal=JWT_SECRET="${JWT_SECRET}" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ All secrets created"
kubectl get secrets -n "$NAMESPACE"