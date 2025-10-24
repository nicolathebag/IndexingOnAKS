#!/bin/bash

set -e

# ================================================================
# Build and Push Docker Images to ACR (Azure Cloud Shell Compatible)
# Uses ACR Build Tasks instead of local Docker
# ================================================================

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Source environment
if [ -f "$HOME/bemind-env.sh" ]; then
    source "$HOME/bemind-env.sh"
elif [ -f "$SCRIPT_DIR/bemind-env.sh" ]; then
    source "$SCRIPT_DIR/bemind-env.sh"
else
    echo "Error: bemind-env.sh not found"
    exit 1
fi

# Parse arguments
VERSION="${1:-v1.0.0}"
BUILD_NUMBER="${2:-$(date +%Y%m%d%H%M%S)}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Building and Pushing to ACR (Cloud Shell)             ║"
echo "╚════════════════════════════════════════════════════════════════╝"

echo ""
echo "Build Configuration:"
echo "  Version:      $VERSION"
echo "  Build Number: $BUILD_NUMBER"
echo "  ACR:          $ACR_LOGIN_SERVER"
echo "  Project Root: $PROJECT_ROOT"
echo "  Method:       Azure ACR Build Tasks (Cloud Shell Compatible)"
echo ""

cd "$PROJECT_ROOT"

# Login to ACR (token-based for Cloud Shell)
echo "Step 1/3: Authenticating with ACR..."
az acr login --name "$ACR_NAME" --expose-token > /dev/null 2>&1 || az acr login --name "$ACR_NAME"
echo "✓ Authenticated with ACR"

# Build and push API image using ACR Build Tasks
echo ""
echo "Step 2/3: Building and pushing API image using ACR Build..."

az acr build \
    --registry "$ACR_NAME" \
    --image "bemind-api:${VERSION}" \
    --image "bemind-api:${VERSION}-${BUILD_NUMBER}" \
    --image "bemind-api:latest" \
    --file "$PROJECT_ROOT/Dockerfile.api" \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg VERSION="${VERSION}" \
    --build-arg BUILD_NUMBER="${BUILD_NUMBER}" \
    "$PROJECT_ROOT"

echo "✓ API image built and pushed"

# Build and push Indexer image using ACR Build Tasks
echo ""
echo "Step 3/3: Building and pushing Indexer image using ACR Build..."

az acr build \
    --registry "$ACR_NAME" \
    --image "bemind-indexer:${VERSION}" \
    --image "bemind-indexer:${VERSION}-${BUILD_NUMBER}" \
    --image "bemind-indexer:latest" \
    --file "$PROJECT_ROOT/Dockerfile.indexer" \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg VERSION="${VERSION}" \
    --build-arg BUILD_NUMBER="${BUILD_NUMBER}" \
    "$PROJECT_ROOT"

echo "✓ Indexer image built and pushed"

# Verify images in ACR
echo ""
echo "Verifying images in ACR..."
echo ""
echo "API Repository:"
az acr repository show-tags \
    --name "$ACR_NAME" \
    --repository bemind-api \
    --orderby time_desc \
    --output table

echo ""
echo "Indexer Repository:"
az acr repository show-tags \
    --name "$ACR_NAME" \
    --repository bemind-indexer \
    --orderby time_desc \
    --output table

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Images pushed successfully:"
echo "  ${ACR_LOGIN_SERVER}/bemind-api:${VERSION}"
echo "  ${ACR_LOGIN_SERVER}/bemind-api:${VERSION}-${BUILD_NUMBER}"
echo "  ${ACR_LOGIN_SERVER}/bemind-indexer:${VERSION}"
echo "  ${ACR_LOGIN_SERVER}/bemind-indexer:${VERSION}-${BUILD_NUMBER}"
echo "════════════════════════════════════════════════════════════════"

# Update deployment files with new version
echo ""
echo "Updating Kubernetes manifests with new image versions..."

# Update API deployment
if [ -f "$PROJECT_ROOT/k8s/api-deployment.yaml" ]; then
    sed -i "s|image:.*bemind-api:.*|image: ${ACR_LOGIN_SERVER}/bemind-api:${VERSION}|g" \
        "$PROJECT_ROOT/k8s/api-deployment.yaml"
    echo "✓ Updated api-deployment.yaml"
fi

# Update environment file
ENV_FILE="$HOME/bemind-env.sh"
if [ -f "$ENV_FILE" ]; then
    if ! grep -q "CURRENT_VERSION" "$ENV_FILE"; then
        echo "export CURRENT_VERSION='$VERSION'" >> "$ENV_FILE"
        echo "export CURRENT_BUILD='$BUILD_NUMBER'" >> "$ENV_FILE"
    else
        sed -i "s/export CURRENT_VERSION=.*/export CURRENT_VERSION='$VERSION'/" "$ENV_FILE"
        sed -i "s/export CURRENT_BUILD=.*/export CURRENT_BUILD='$BUILD_NUMBER'/" "$ENV_FILE"
    fi
    echo "✓ Updated $ENV_FILE"
fi

echo ""
echo "✓ Build and push completed successfully using ACR Build Tasks!"
echo ""
echo "To deploy: bash $SCRIPT_DIR/deploy-with-existing-services.sh $VERSION"