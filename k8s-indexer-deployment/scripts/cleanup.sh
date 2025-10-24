#!/bin/bash

# Cleanup script for Kubernetes resources

# Define the namespace
NAMESPACE="your-namespace"

# Delete the API deployment and service
kubectl delete deployment api-deployment -n $NAMESPACE
kubectl delete service api-service -n $NAMESPACE

# Delete the indexer cron job
kubectl delete cronjob indexer-cronjob -n $NAMESPACE

# Delete the ConfigMap and Secrets
kubectl delete configmap your-configmap -n $NAMESPACE
kubectl delete secret your-secret -n $NAMESPACE

# Delete the RBAC resources
kubectl delete -f k8s/rbac.yaml -n $NAMESPACE

# Optionally, delete the namespace if no longer needed
# kubectl delete namespace $NAMESPACE

echo "Cleanup completed."