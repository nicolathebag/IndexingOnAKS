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
echo "Verifying ACR..."
ACR_EXISTS=$(az acr show \
    --name "$ACR_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "name" \
    -o tsv 2>/dev/null || echo "")

if [ -z "$ACR_EXISTS" ]; then
    echo "Error: ACR '$ACR_NAME' not found in resource group '$RESOURCE_GROUP'"
    echo "Please create the ACR first or update ACR_NAME in bemind-env.sh"
    exit 1
else
    echo "✓ ACR exists: $ACR_NAME"
fi

# Get ACR login server
export ACR_LOGIN_SERVER=$(az acr show \
    --name "$ACR_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query loginServer \
    -o tsv)

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "ACR Configuration:"
echo "  Name:         $ACR_NAME"
echo "  Login Server: $ACR_LOGIN_SERVER"
echo "  Note:         Assuming ACR is already attached to AKS"
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
