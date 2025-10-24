#!/bin/bash
# ================================================================
# BeMind Azure Environment Configuration
# UPDATE THESE VALUES FOR YOUR ENVIRONMENT
# ================================================================

# Azure Core Settings
export SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export RESOURCE_GROUP="DEV-BeMind"
export LOCATION="Sweden Central"

# AKS Configuration
export AKS_CLUSTER_NAME="bemind_aks"
export AKS_NODE_COUNT="3"
export AKS_NODE_VM_SIZE="Standard_D4s_v3"
export NAMESPACE="bemindindexer"

# ACR Configuration
export ACR_NAME="devbemindcontainerregistryse"
export ACR_SKU="Standard"

# Azure Services - UPDATE WITH YOUR ACTUAL NAMES
export STORAGE_ACCOUNT_NAME="avadatastore"
export SEARCH_SERVICE_NAME="be-tt-ava-aisearch-bechtle"
export OPENAI_RESOURCE_NAME="be-tt-ava-openaieu"

# Domain & Email
export DOMAIN_NAME="api.bemind.bemindindexer.com"
export ADMIN_EMAIL="prasad.jallipalli@bearingpoint.com"

# Application Configuration
export API_IMAGE_NAME="bemind-api"
export INDEXER_IMAGE_NAME="bemind-indexer"
export CURRENT_VERSION="v1.0.0"

# OpenAI Configuration
export OPENAI_GPT4_DEPLOYMENT="gpt-4"
export OPENAI_EMBEDDING_DEPLOYMENT="text-embedding-ada-002"
export OPENAI_API_VERSION="2024-02-01"

# Search Configuration
export SEARCH_API_VERSION="2023-11-01"

# Computed values (don't change)
export ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

echo "✓ Environment configured"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  AKS Cluster:    $AKS_CLUSTER_NAME"
echo "  ACR:            $ACR_LOGIN_SERVER"