#!/bin/bash

# Set the namespace
NAMESPACE="bemindindexer"

# Apply the Kubernetes configurations
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml -n $NAMESPACE
kubectl apply -f k8s/secrets.yaml -n $NAMESPACE
kubectl apply -f k8s/rbac.yaml -n $NAMESPACE
kubectl apply -f k8s/api-deployment.yaml -n $NAMESPACE
kubectl apply -f k8s/api-service.yaml -n $NAMESPACE
kubectl apply -f k8s/indexer-cronjob.yaml -n $NAMESPACE

echo "Deployment completed successfully."
