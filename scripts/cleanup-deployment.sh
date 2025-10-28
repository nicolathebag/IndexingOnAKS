#!/bin/bash
# ================================================================
# BeMind Deployment Cleanup Script
# Removes all resources tracked during deployment
# ================================================================

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TRACKING_FILE="$SCRIPT_DIR/.bemind-deployed-resources.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║   BeMind Deployment Cleanup                                    ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"

# Check if tracking file exists
if [[ ! -f "$TRACKING_FILE" ]]; then
    echo -e "${RED}Error: Resource tracking file not found: $TRACKING_FILE${NC}"
    echo -e "${YELLOW}No deployment found to clean up.${NC}"
    exit 1
fi

echo "Reading tracked resources from: $TRACKING_FILE"
echo ""

# Display what will be deleted
echo -e "${YELLOW}The following resources will be deleted:${NC}"
echo ""
grep -E "^(namespace|deployment|service|hpa|configmap|secret|serviceaccount|role|rolebinding|image)=" "$TRACKING_FILE" | sed 's/^/  - /'
echo ""

# Confirm deletion
read -p "Are you sure you want to delete all these resources? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo -e "${YELLOW}Cleanup cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting cleanup...${NC}"

# Parse tracking file
NAMESPACE=$(grep "^namespace=" "$TRACKING_FILE" | cut -d'=' -f2)

if [[ -z "$NAMESPACE" ]]; then
    echo -e "${RED}Error: Namespace not found in tracking file${NC}"
    exit 1
fi

echo -e "${GREEN}Using namespace: $NAMESPACE${NC}"

# Delete Kubernetes resources
echo ""
echo -e "${YELLOW}Step 1/5: Deleting Kubernetes deployments, services, and HPA...${NC}"

# Delete HPA
HPAS=$(grep "^hpa=" "$TRACKING_FILE" | cut -d'=' -f2)
for hpa in $HPAS; do
    if kubectl get hpa "$hpa" -n "$NAMESPACE" > /dev/null 2>&1; then
        echo "  Deleting HPA: $hpa"
        kubectl delete hpa "$hpa" -n "$NAMESPACE" --timeout=30s || echo "    Warning: Failed to delete HPA $hpa"
    fi
done

# Delete Deployments
DEPLOYMENTS=$(grep "^deployment=" "$TRACKING_FILE" | cut -d'=' -f2)
for deploy in $DEPLOYMENTS; do
    if kubectl get deployment "$deploy" -n "$NAMESPACE" > /dev/null 2>&1; then
        echo "  Deleting Deployment: $deploy"
        kubectl delete deployment "$deploy" -n "$NAMESPACE" --timeout=60s || echo "    Warning: Failed to delete deployment $deploy"
    fi
done

# Delete Services
SERVICES=$(grep "^service=" "$TRACKING_FILE" | cut -d'=' -f2)
for svc in $SERVICES; do
    if kubectl get service "$svc" -n "$NAMESPACE" > /dev/null 2>&1; then
        echo "  Deleting Service: $svc"
        kubectl delete service "$svc" -n "$NAMESPACE" --timeout=30s || echo "    Warning: Failed to delete service $svc"
    fi
done

echo -e "${GREEN}✓ Deployments, services, and HPA deleted${NC}"

# Delete ConfigMaps
echo ""
echo -e "${YELLOW}Step 2/5: Deleting ConfigMaps...${NC}"
CONFIGMAPS=$(grep "^configmap=" "$TRACKING_FILE" | cut -d'=' -f2)
for cm in $CONFIGMAPS; do
    if kubectl get configmap "$cm" -n "$NAMESPACE" > /dev/null 2>&1; then
        echo "  Deleting ConfigMap: $cm"
        kubectl delete configmap "$cm" -n "$NAMESPACE" --timeout=30s || echo "    Warning: Failed to delete configmap $cm"
    fi
done
echo -e "${GREEN}✓ ConfigMaps deleted${NC}"

# Delete Secrets
echo ""
echo -e "${YELLOW}Step 3/5: Deleting Secrets...${NC}"
SECRETS=$(grep "^secret=" "$TRACKING_FILE" | cut -d'=' -f2)
for secret in $SECRETS; do
    if kubectl get secret "$secret" -n "$NAMESPACE" > /dev/null 2>&1; then
        echo "  Deleting Secret: $secret"
        kubectl delete secret "$secret" -n "$NAMESPACE" --timeout=30s || echo "    Warning: Failed to delete secret $secret"
    fi
done
echo -e "${GREEN}✓ Secrets deleted${NC}"

# Delete RBAC resources
echo ""
echo -e "${YELLOW}Step 4/5: Deleting RBAC resources...${NC}"

# Delete RoleBindings
ROLEBINDINGS=$(grep "^rolebinding=" "$TRACKING_FILE" | cut -d'=' -f2)
for rb in $ROLEBINDINGS; do
    if kubectl get rolebinding "$rb" -n "$NAMESPACE" > /dev/null 2>&1; then
        echo "  Deleting RoleBinding: $rb"
        kubectl delete rolebinding "$rb" -n "$NAMESPACE" --timeout=30s || echo "    Warning: Failed to delete rolebinding $rb"
    fi
done

# Delete Roles
ROLES=$(grep "^role=" "$TRACKING_FILE" | cut -d'=' -f2)
for role in $ROLES; do
    if kubectl get role "$role" -n "$NAMESPACE" > /dev/null 2>&1; then
        echo "  Deleting Role: $role"
        kubectl delete role "$role" -n "$NAMESPACE" --timeout=30s || echo "    Warning: Failed to delete role $role"
    fi
done

# Delete ServiceAccounts
SAS=$(grep "^serviceaccount=" "$TRACKING_FILE" | cut -d'=' -f2)
for sa in $SAS; do
    if kubectl get serviceaccount "$sa" -n "$NAMESPACE" > /dev/null 2>&1; then
        echo "  Deleting ServiceAccount: $sa"
        kubectl delete serviceaccount "$sa" -n "$NAMESPACE" --timeout=30s || echo "    Warning: Failed to delete serviceaccount $sa"
    fi
done

echo -e "${GREEN}✓ RBAC resources deleted${NC}"

# Optional: Delete container images from ACR
echo ""
echo -e "${YELLOW}Step 5/5: Container images in ACR...${NC}"
read -p "Do you want to delete container images from ACR? (yes/no): " DELETE_IMAGES

if [[ "$DELETE_IMAGES" == "yes" ]]; then
    ACR_NAME=$(grep "^acr_name=" "$TRACKING_FILE" | cut -d'=' -f2)
    if [[ -n "$ACR_NAME" ]]; then
        IMAGES=$(grep "^image=" "$TRACKING_FILE" | cut -d'=' -f2)
        for image in $IMAGES; do
            # Extract repository and tag
            REPO=$(echo "$image" | sed "s|${ACR_NAME}.azurecr.io/||" | cut -d':' -f1)
            TAG=$(echo "$image" | cut -d':' -f2)
            
            echo "  Deleting image: $REPO:$TAG"
            az acr repository delete \
                --name "$ACR_NAME" \
                --image "$REPO:$TAG" \
                --yes 2>/dev/null || echo "    Warning: Failed to delete image $REPO:$TAG"
        done
        echo -e "${GREEN}✓ Container images deleted from ACR${NC}"
    fi
else
    echo -e "${YELLOW}Skipping ACR image deletion${NC}"
fi

# Archive the tracking file
echo ""
echo -e "${YELLOW}Archiving tracking file...${NC}"
ARCHIVE_FILE="${TRACKING_FILE}.$(date +%Y%m%d-%H%M%S).bak"
mv "$TRACKING_FILE" "$ARCHIVE_FILE"
echo -e "${GREEN}✓ Tracking file archived to: $ARCHIVE_FILE${NC}"

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Cleanup completed successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Note: The namespace '$NAMESPACE' was not deleted."
echo "To delete the namespace, run:"
echo "  kubectl delete namespace $NAMESPACE"
