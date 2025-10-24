#!/bin/bash

set -e

# ================================================================
# Azure Container Registry Setup Script
# Creates ACR with recommended production settings
# Idempotent - safe to run multiple times
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
echo ""
echo "Checking if ACR exists..."
ACR_EXISTS=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" 2>/dev/null || echo "")

if [ -z "$ACR_EXISTS" ]; then
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

# Check and attach ACR to AKS (only if not already attached)
echo ""
echo "Checking ACR attachment to AKS..."

# Try to attach and capture the output
ATTACH_OUTPUT=$(az aks update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --attach-acr "$ACR_NAME" 2>&1 || echo "")

if echo "$ATTACH_OUTPUT" | grep -q "role assignment already exists\|is already attached"; then
    echo "✓ ACR already attached to AKS (skipping)"
elif echo "$ATTACH_OUTPUT" | grep -q "error\|Error"; then
    echo "⚠ Warning: Could not verify ACR attachment"
    echo "$ATTACH_OUTPUT"
else
    echo "✓ ACR attached to AKS with managed identity"
fi

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
echo "  Status:       Ready for use"
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