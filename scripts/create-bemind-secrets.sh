#!/bin/bash

# Script to extract Azure service credentials from existing secrets in 'bemind' namespace
# and create the complete 'bemind-secrets' in 'bemindindexer' namespace

set -e

echo "Extracting Azure OpenAI credentials..."
kubectl get secret azure-openai-secret -n bemind -o jsonpath='{.data}' | jq -r 'to_entries[] | "AZURE_OPENAI_\(.key | ascii_upcase | sub("-"; "_"))=\(.value | @base64d)"' > /tmp/openai.env

echo "Extracting Azure Search credentials..."
kubectl get secret azure-search-secret -n bemind -o jsonpath='{.data}' | jq -r 'to_entries[] | "AZURE_SEARCH_\(.key | ascii_upcase | sub("-"; "_"))=\(.value | @base64d)"' > /tmp/search.env

echo "Extracting Azure Storage credentials..."
kubectl get secret azure-storage-secret -n bemind -o jsonpath='{.data}' | jq -r 'to_entries[] | "AZURE_STORAGE_\(.key | ascii_upcase | sub("-"; "_"))=\(.value | @base64d)"' > /tmp/storage.env

echo "Extracting JWT_SECRET..."
kubectl get secret api-secrets -n bemind -o jsonpath='{.data.JWT_SECRET}' | base64 -d > /tmp/jwt.env
echo "JWT_SECRET=$(cat /tmp/jwt.env)" > /tmp/jwt_final.env

echo "Combining all credentials..."
cat /tmp/openai.env /tmp/search.env /tmp/storage.env /tmp/jwt_final.env > /tmp/combined.env

echo "Creating bemind-secrets in bemindindexer namespace..."
kubectl create secret generic bemind-secrets --from-env-file=/tmp/combined.env -n bemindindexer --dry-run=client -o yaml | kubectl apply -f -

echo "Cleaning up temporary files..."
rm -f /tmp/openai.env /tmp/search.env /tmp/storage.env /tmp/jwt.env /tmp/jwt_final.env /tmp/combined.env

echo "Secret creation complete. Verify with: kubectl get secret bemind-secrets -n bemindindexer"