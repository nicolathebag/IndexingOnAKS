#!/bin/bash

set -e

# ================================================================
# Create Kubernetes Secrets from Existing Azure Services
# This script uses provided credentials instead of fetching them
# ================================================================

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
echo "║     Creating Secrets from Existing Azure Services             ║"
echo "╚════════════════════════════════════════════════════════════════╝"

# ================================================================
# Check if .bemind-credentials.env exists
# ================================================================
CREDS_FILE="$HOME/.bemind-credentials.env"

if [ -f "$CREDS_FILE" ]; then
    echo ""
    echo "Found credentials file: $CREDS_FILE"
    read -p "Use credentials from this file? (y/n): " USE_FILE
    
    if [ "$USE_FILE" = "y" ] || [ "$USE_FILE" = "Y" ]; then
        source "$CREDS_FILE"
        
        # Validate required variables
        if [ -z "$AZURE_STORAGE_CONNECTION_STRING" ] || \
           [ -z "$AZURE_SEARCH_ENDPOINT" ] || \
           [ -z "$AZURE_SEARCH_ADMIN_KEY" ] || \
           [ -z "$AZURE_OPENAI_ENDPOINT" ] || \
           [ -z "$AZURE_OPENAI_API_KEY" ]; then
            echo "Error: Missing required credentials in $CREDS_FILE"
            exit 1
        fi
        
        echo "✓ Loaded credentials from file"
    else
        # Interactive prompts below
        INTERACTIVE=true
    fi
else
    INTERACTIVE=true
fi

# ================================================================
# Interactive credential collection
# ================================================================
if [ "$INTERACTIVE" = "true" ]; then
    # Azure Storage
    echo ""
    echo "=== Azure Storage Credentials ==="
    read -p "Storage Account Name [$STORAGE_ACCOUNT_NAME]: " input_storage_name
    STORAGE_ACCOUNT_NAME=${input_storage_name:-$STORAGE_ACCOUNT_NAME}

    read -p "Storage Account Key (or press Enter to input connection string): " STORAGE_KEY

    if [ -z "$STORAGE_KEY" ]; then
        echo "Enter Storage Connection String:"
        read -s AZURE_STORAGE_CONNECTION_STRING
    else
        AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;AccountName=${STORAGE_ACCOUNT_NAME};AccountKey=${STORAGE_KEY};EndpointSuffix=core.windows.net"
    fi

    # Azure Cognitive Search
    echo ""
    echo "=== Azure Cognitive Search Credentials ==="
    read -p "Search Service Endpoint [$SEARCH_ENDPOINT]: " input_search_endpoint
    AZURE_SEARCH_ENDPOINT=${input_search_endpoint:-$SEARCH_ENDPOINT}

    echo "Enter Search Admin Key:"
    read -s AZURE_SEARCH_ADMIN_KEY

    # Azure OpenAI
    echo ""
    echo "=== Azure OpenAI Credentials ==="
    read -p "OpenAI Endpoint [$OPENAI_ENDPOINT]: " input_openai_endpoint
    AZURE_OPENAI_ENDPOINT=${input_openai_endpoint:-$OPENAI_ENDPOINT}

    echo "Enter OpenAI API Key:"
    read -s AZURE_OPENAI_API_KEY

    read -p "OpenAI Embedding Deployment Name [$OPENAI_EMBEDDING_DEPLOYMENT]: " input_embedding
    AZURE_OPENAI_EMBEDDING_DEPLOYMENT=${input_embedding:-$OPENAI_EMBEDDING_DEPLOYMENT}
fi

# Generate JWT Secret if not exists
if [ -z "$JWT_SECRET" ]; then
    echo ""
    echo "=== Generating JWT Secret ==="
    JWT_SECRET=$(openssl rand -base64 32)
fi

# ================================================================
# Connect to AKS
# ================================================================
echo ""
echo "Connecting to AKS..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

# Create namespace
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ================================================================
# Create Kubernetes Secrets
# ================================================================
echo ""
echo "Creating Kubernetes secrets..."

# Azure OpenAI Secret
kubectl create secret generic azure-openai-secret \
    --from-literal=AZURE_OPENAI_ENDPOINT="${AZURE_OPENAI_ENDPOINT}" \
    --from-literal=AZURE_OPENAI_API_KEY="${AZURE_OPENAI_API_KEY}" \
    --from-literal=AZURE_OPENAI_API_VERSION="${OPENAI_API_VERSION}" \
    --from-literal=AZURE_OPENAI_EMBEDDING_DEPLOYMENT="${AZURE_OPENAI_EMBEDDING_DEPLOYMENT:-$OPENAI_EMBEDDING_DEPLOYMENT}" \
    --from-literal=AZURE_OPENAI_GPT4_DEPLOYMENT="${OPENAI_GPT4_DEPLOYMENT}" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Azure OpenAI secret created"

# Azure Cognitive Search Secret
kubectl create secret generic azure-search-secret \
    --from-literal=AZURE_SEARCH_ENDPOINT="${AZURE_SEARCH_ENDPOINT}" \
    --from-literal=AZURE_SEARCH_KEY="${AZURE_SEARCH_ADMIN_KEY}" \
    --from-literal=AZURE_SEARCH_API_VERSION="${SEARCH_API_VERSION}" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Azure Search secret created"

# Azure Storage Secret
kubectl create secret generic azure-storage-secret \
    --from-literal=AZURE_STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_NAME}" \
    --from-literal=AZURE_STORAGE_CONNECTION_STRING="${AZURE_STORAGE_CONNECTION_STRING}" \
    --from-literal=AZURE_STORAGE_ENDPOINT="${STORAGE_ENDPOINT}" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Azure Storage secret created"

# API Secrets (JWT)
kubectl create secret generic api-secrets \
    --from-literal=JWT_SECRET="${JWT_SECRET}" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ API secrets created"

# ================================================================
# Verify Secrets
# ================================================================
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Secrets created successfully:"
kubectl get secrets -n "$NAMESPACE"
echo "════════════════════════════════════════════════════════════════"

echo ""
echo "✓ All secrets created from existing Azure services"
echo ""
echo "IMPORTANT: Save JWT secret securely!"
echo "JWT Secret: $JWT_SECRET"