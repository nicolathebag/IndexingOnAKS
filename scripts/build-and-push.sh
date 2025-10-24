#!/bin/bash

set -e

# ================================================================
# Build and Push Docker Images to ACR (Azure Cloud Shell Compatible)
# Checks if images exist before rebuilding - optimized for speed
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
FORCE_BUILD="${3:-false}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Building and Pushing to ACR (Cloud Shell)             ║"
echo "╚════════════════════════════════════════════════════════════════╝"

echo ""
echo "Build Configuration:"
echo "  Version:      $VERSION"
echo "  Build Number: $BUILD_NUMBER"
echo "  ACR:          $ACR_LOGIN_SERVER"
echo "  Force Build:  $FORCE_BUILD"
echo ""

cd "$PROJECT_ROOT"

# Login to ACR
echo "Step 1/5: Authenticating with ACR..."
az acr login --name "$ACR_NAME" --expose-token > /dev/null 2>&1 || az acr login --name "$ACR_NAME"
echo "✓ Authenticated with ACR"

# Function to check if image exists in ACR
check_image_exists() {
    local image_name=$1
    local tag=$2
    
    az acr repository show-tags \
        --name "$ACR_NAME" \
        --repository "$image_name" \
        --output tsv 2>/dev/null | grep -q "^${tag}$"
    return $?
}

# Check API image
echo ""
echo "Step 2/5: Checking if API image exists..."
API_EXISTS=false
if check_image_exists "bemind-api" "$VERSION"; then
    echo "✓ Image bemind-api:$VERSION already exists in ACR"
    API_EXISTS=true
else
    echo "ℹ Image bemind-api:$VERSION not found in ACR"
fi

# Check Indexer image
echo ""
echo "Step 3/5: Checking if Indexer image exists..."
INDEXER_EXISTS=false
if check_image_exists "bemind-indexer" "$VERSION"; then
    echo "✓ Image bemind-indexer:$VERSION already exists in ACR"
    INDEXER_EXISTS=true
else
    echo "ℹ Image bemind-indexer:$VERSION not found in ACR"
fi

# Build API image if needed
echo ""
echo "Step 4/5: Processing API image..."
if [ "$API_EXISTS" = true ] && [ "$FORCE_BUILD" != "true" ]; then
    echo "⏭ Skipping API build (image already exists)"
    echo "  Use '$0 $VERSION auto true' to force rebuild"
else
    echo "Building and pushing API image..."
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
fi

# Build Indexer image if needed
echo ""
echo "Step 5/5: Processing Indexer image..."
if [ "$INDEXER_EXISTS" = true ] && [ "$FORCE_BUILD" != "true" ]; then
    echo "⏭ Skipping Indexer build (image already exists)"
    echo "  Use '$0 $VERSION auto true' to force rebuild"
else
    echo "Building and pushing Indexer image..."
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
fi

# Display results
echo ""
echo "════════════════════════════════════════════════════════════════"
if [ "$API_EXISTS" = true ] && [ "$INDEXER_EXISTS" = true ] && [ "$FORCE_BUILD" != "true" ]; then
    echo "All images already exist in ACR - no build needed"
    echo ""
    echo "Existing images:"
elif [ "$API_EXISTS" = true ] || [ "$INDEXER_EXISTS" = true ]; then
    echo "Partial build completed (some images already existed)"
    echo ""
    echo "Images in ACR:"
else
    echo "Build completed successfully"
    echo ""
    echo "Images pushed to ACR:"
fi

echo "  ${ACR_LOGIN_SERVER}/bemind-api:${VERSION}"
echo "  ${ACR_LOGIN_SERVER}/bemind-indexer:${VERSION}"
echo "════════════════════════════════════════════════════════════════"

# Update deployment files with version
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