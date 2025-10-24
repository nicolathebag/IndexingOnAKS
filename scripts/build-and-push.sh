#!/bin/bash

set -e

# ================================================================
# Build and Push Docker Images to ACR
# Supports semantic versioning and latest tag
# ================================================================

source ~/deploy-env.sh

# Parse arguments
VERSION="${1:-v1.0.0}"
BUILD_NUMBER="${2:-$(date +%Y%m%d%H%M%S)}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Building and Pushing to ACR                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"

echo ""
echo "Build Configuration:"
echo "  Version:      $VERSION"
echo "  Build Number: $BUILD_NUMBER"
echo "  ACR:          $ACR_LOGIN_SERVER"
echo ""

cd ~/k8s-indexer-deployment

# Login to ACR
echo "Step 1/4: Logging into ACR..."
az acr login --name $ACR_NAME
echo "✓ Logged in to ACR"

# Build API image
echo ""
echo "Step 2/4: Building API image..."

docker build \
    --file Dockerfile.api \
    --tag ${ACR_LOGIN_SERVER}/bemind-api:${VERSION} \
    --tag ${ACR_LOGIN_SERVER}/bemind-api:${VERSION}-${BUILD_NUMBER} \
    --tag ${ACR_LOGIN_SERVER}/bemind-api:latest \
    --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg VERSION=${VERSION} \
    --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
    --label org.opencontainers.image.created=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    --label org.opencontainers.image.version=${VERSION} \
    --label org.opencontainers.image.revision=${BUILD_NUMBER} \
    .

echo "✓ API image built"

# Build Indexer image
echo ""
echo "Step 3/4: Building Indexer image..."

docker build \
    --file Dockerfile.indexer \
    --tag ${ACR_LOGIN_SERVER}/bemind-indexer:${VERSION} \
    --tag ${ACR_LOGIN_SERVER}/bemind-indexer:${VERSION}-${BUILD_NUMBER} \
    --tag ${ACR_LOGIN_SERVER}/bemind-indexer:latest \
    --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg VERSION=${VERSION} \
    --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
    --label org.opencontainers.image.created=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    --label org.opencontainers.image.version=${VERSION} \
    --label org.opencontainers.image.revision=${BUILD_NUMBER} \
    .

echo "✓ Indexer image built"

# Push images to ACR
echo ""
echo "Step 4/4: Pushing images to ACR..."

# Push API images
echo "  Pushing API images..."
docker push ${ACR_LOGIN_SERVER}/bemind-api:${VERSION}
docker push ${ACR_LOGIN_SERVER}/bemind-api:${VERSION}-${BUILD_NUMBER}
docker push ${ACR_LOGIN_SERVER}/bemind-api:latest

# Push Indexer images
echo "  Pushing Indexer images..."
docker push ${ACR_LOGIN_SERVER}/bemind-indexer:${VERSION}
docker push ${ACR_LOGIN_SERVER}/bemind-indexer:${VERSION}-${BUILD_NUMBER}
docker push ${ACR_LOGIN_SERVER}/bemind-indexer:latest

echo "✓ All images pushed to ACR"

# Verify images in ACR
echo ""
echo "Verifying images in ACR..."
echo ""
echo "API Repository:"
az acr repository show-tags \
    --name $ACR_NAME \
    --repository bemind-api \
    --orderby time_desc \
    --output table

echo ""
echo "Indexer Repository:"
az acr repository show-tags \
    --name $ACR_NAME \
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
sed -i "s|image:.*bemind-api:.*|image: ${ACR_LOGIN_SERVER}/bemind-api:${VERSION}|g" \
    k8s/api-deployment.yaml

# Update environment file
if ! grep -q "CURRENT_VERSION" ~/deploy-env.sh; then
    echo "export CURRENT_VERSION='$VERSION'" >> ~/deploy-env.sh
    echo "export CURRENT_BUILD='$BUILD_NUMBER'" >> ~/deploy-env.sh
else
    sed -i "s/export CURRENT_VERSION=.*/export CURRENT_VERSION='$VERSION'/" ~/deploy-env.sh
    sed -i "s/export CURRENT_BUILD=.*/export CURRENT_BUILD='$BUILD_NUMBER'/" ~/deploy-env.sh
fi

echo "✓ Manifests updated"
echo ""
echo "✓ Build and push completed successfully!"
echo ""
echo "To deploy: bash scripts/deploy.sh"