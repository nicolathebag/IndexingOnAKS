#!/bin/bash
# ================================================================
# Azure Environment Configuration
# ================================================================

# Azure Core Settings
export SUBSCRIPTION_ID="$(az account show --query id -o tsv 2>/dev/null || echo '')"
export RESOURCE_GROUP="DEV-IndexingOnAKS"
export LOCATION="swedencentral"

# AKS Configuration
export AKS_CLUSTER_NAME="indexing_aks"
export NAMESPACE="indexer"

# ACR Configuration
export ACR_NAME="devindexercontainerregistry"
export ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

# Azure Storage
export STORAGE_ACCOUNT_NAME="avadatastore"
export STORAGE_ENDPOINT="https://avadatastore.blob.core.windows.net"

# Azure Cognitive Search
export SEARCH_SERVICE_NAME="be-tt-ava-aisearch-bechtle"
export SEARCH_ENDPOINT="https://be-tt-ava-aisearch-bechtle.search.windows.net"

# Azure OpenAI
export OPENAI_RESOURCE_NAME="be-tt-ava-openaieu"
export OPENAI_ENDPOINT="https://be-tt-ava-openaieu.openai.azure.com/"

# OpenAI Configuration
export OPENAI_GPT4_DEPLOYMENT="gpt-4"
export OPENAI_EMBEDDING_DEPLOYMENT="text-embedding-ada-002"
export OPENAI_API_VERSION="2024-02-01"

# Search Configuration
export SEARCH_API_VERSION="2023-11-01"

# Application Version
export CURRENT_VERSION="v1.0.0"

echo "✓ Environment configured for Azure Cloud Shell"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  AKS Cluster:    $AKS_CLUSTER_NAME"
echo "  ACR:            $ACR_LOGIN_SERVER"
