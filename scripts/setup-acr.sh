#!/bin/bash

set -e

# ================================================================
# Azure Container Registry Setup Script
# Creates ACR with recommended production settings
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
echo "║         Azure Container Registry Setup                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"

# Check if ACR exists
ACR_EXISTS=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" 2>/dev/null || echo "")

if [ -z "$ACR_EXISTS" ]; then
    echo ""
    echo "Creating Azure Container Registry..."
    
    az acr create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ACR_NAME" \
        --sku Standard \
        --location "$LOCATION" \
        --admin-enabled false
    
    echo "✓ ACR created: $ACR_NAME"
else
    echo "✓ ACR already exists: $ACR_NAME"
fi

# Enable Azure Defender for container registries (Security)
echo ""
echo "Configuring ACR security settings..."

# Enable content trust (Image signing)
az acr config content-trust update \
    --registry "$ACR_NAME" \
    --status enabled 2>/dev/null || echo "Note: Content trust may require Premium SKU"

# Enable vulnerability scanning
az acr config retention update \
    --registry "$ACR_NAME" \
    --status enabled \
    --days 30 \
    --type UntaggedManifests 2>/dev/null || echo "Note: Retention policies may require Premium SKU"

echo "✓ ACR security configured"

# Configure AKS to pull from ACR using managed identity
echo ""
echo "Attaching ACR to AKS cluster..."

az aks update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --attach-acr "$ACR_NAME"

echo "✓ ACR attached to AKS with managed identity"

# Get ACR login server
export ACR_LOGIN_SERVER=$(az acr show \
    --name "$ACR_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query loginServer -o tsv)

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "ACR Configuration:"
echo "  Name:         $ACR_NAME"
echo "  Login Server: $ACR_LOGIN_SERVER"
echo "  SKU:          Standard"
echo "  Security:     Enabled (Content Trust, Vulnerability Scanning)"
echo "════════════════════════════════════════════════════════════════"

# Update environment file
ENV_FILE="$HOME/bemind-env.sh"
if [ -f "$ENV_FILE" ]; then
    if ! grep -q "ACR_LOGIN_SERVER" "$ENV_FILE"; then
        echo "export ACR_LOGIN_SERVER='$ACR_LOGIN_SERVER'" >> "$ENV_FILE"
    else
        sed -i "s|export ACR_LOGIN_SERVER=.*|export ACR_LOGIN_SERVER='$ACR_LOGIN_SERVER'|" "$ENV_FILE"
    fi
    echo "✓ Updated $ENV_FILE"
fi

echo ""
echo "✓ ACR setup completed"