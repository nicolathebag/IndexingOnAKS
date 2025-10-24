#!/bin/bash
# ================================================================
# BeMind Azure Environment Configuration
# Using EXISTING Azure Services via Endpoints
# ================================================================

# Azure Core Settings
export SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export RESOURCE_GROUP="DEV-BeMind"
export LOCATION="Sweden Central"

# AKS Configuration
export AKS_CLUSTER_NAME="bemind_aks"
export NAMESPACE="bemind"

# ACR Configuration
export ACR_NAME="devbemindcontainerregistryse"
export ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

# ================================================================
# EXISTING AZURE SERVICES - UPDATE THESE ENDPOINTS
# ================================================================

# Azure Storage - EXISTING SERVICE
export STORAGE_ACCOUNT_NAME="avadatastore"
export STORAGE_ENDPOINT="https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net"

# You'll need to provide the connection string or access key

# Azure Cognitive Search - EXISTING SERVICE
export SEARCH_ENDPOINT="https://be-tt-ava-aisearch-bechtle.search.windows.net"

# You'll need to provide the admin key

# Azure OpenAI - EXISTING SERVICE
export OPENAI_ENDPOINT="https://be-tt-ava-openaieu.openai.azure.com/"

# You'll need to provide the API key

# OpenAI Deployment Names
export OPENAI_GPT4_DEPLOYMENT="gpt-4"
export OPENAI_EMBEDDING_DEPLOYMENT="text-embedding-ada-002"
export OPENAI_API_VERSION="2024-02-01"

# Search Configuration
export SEARCH_API_VERSION="2023-11-01"

# Application Version
export CURRENT_VERSION="v1.0.0"

echo "✓ Environment configured with existing Azure services"
echo "  Storage:  $STORAGE_ENDPOINT"
echo "  Search:   $SEARCH_ENDPOINT"
echo "  OpenAI:   $OPENAI_ENDPOINT"