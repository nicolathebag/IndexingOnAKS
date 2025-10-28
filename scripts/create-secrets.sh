#!/bin/bash

# Script to extract Azure service credentials from existing secrets in 'indexer' namespace
# and create the complete 'indexer-secrets' in 'indexer' namespace

set -e

echo "Extracting Azure OpenAI credentials..."
kubectl get secret azure-openai-secret -n indexer -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key | ascii_upcase | sub("-"; "_"))=\(.value | @base64d)"' > /tmp/openai.env

echo "Extracting Azure Search credentials..."
kubectl get secret azure-search-secret -n indexer -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key | ascii_upcase | sub("-"; "_"))=\(.value | @base64d)"' > /tmp/search.env

echo "Extracting Azure Storage credentials..."
kubectl get secret azure-storage-secret -n indexer -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key | ascii_upcase | sub("-"; "_"))=\(.value | @base64d)"' > /tmp/storage.env

echo "Extracting JWT_SECRET..."
kubectl get secret api-secrets -n indexer -o jsonpath='{.data.JWT_SECRET}' | base64 -d > /tmp/jwt.env
echo "JWT_SECRET=$(cat /tmp/jwt.env)" > /tmp/jwt_final.env

echo "Combining all credentials..."
cat /tmp/openai.env /tmp/search.env /tmp/storage.env /tmp/jwt_final.env > /tmp/combined.env

echo "Creating indexer-secrets in indexer namespace..."
kubectl create secret generic indexer-secrets --from-env-file=/tmp/combined.env -n indexer --dry-run=client -o yaml | kubectl apply -f -

echo "Cleaning up temporary files..."
rm -f /tmp/openai.env /tmp/search.env /tmp/storage.env /tmp/jwt.env /tmp/jwt_final.env /tmp/combined.env

echo "Secret creation complete. Verify with: kubectl get secret indexer-secrets -n indexer"