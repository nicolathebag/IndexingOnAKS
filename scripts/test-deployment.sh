#!/bin/bash
# ================================================================
# BeMind API Deployment Test Script
# Comprehensive testing of deployed application
# ================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}BeMind API Deployment Tests${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Test 1: Pod Status
echo -e "${YELLOW}Test 1: Checking Pod Status...${NC}"
POD_STATUS=$(kubectl get pods -n default -l app=bemind-api -o jsonpath='{.items[*].status.phase}')
if [[ "$POD_STATUS" == *"Running"* ]]; then
    echo -e "${GREEN}✓ Pods are running${NC}"
    kubectl get pods -n default -l app=bemind-api
else
    echo -e "${RED}✗ Pods are not running properly${NC}"
    kubectl get pods -n default -l app=bemind-api
    exit 1
fi
echo ""

# Test 2: Deployment Status
echo -e "${YELLOW}Test 2: Checking Deployment Status...${NC}"
READY_REPLICAS=$(kubectl get deployment bemind-api -n default -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get deployment bemind-api -n default -o jsonpath='{.spec.replicas}')
if [ "$READY_REPLICAS" == "$DESIRED_REPLICAS" ]; then
    echo -e "${GREEN}✓ All replicas are ready ($READY_REPLICAS/$DESIRED_REPLICAS)${NC}"
else
    echo -e "${RED}✗ Not all replicas are ready ($READY_REPLICAS/$DESIRED_REPLICAS)${NC}"
    exit 1
fi
echo ""

# Test 3: Service Endpoints
echo -e "${YELLOW}Test 3: Checking Service Endpoints...${NC}"
ENDPOINTS=$(kubectl get endpoints bemind-api-service -n default -o jsonpath='{.subsets[*].addresses[*].ip}')
if [ -n "$ENDPOINTS" ]; then
    echo -e "${GREEN}✓ Service has endpoints: $ENDPOINTS${NC}"
else
    echo -e "${RED}✗ Service has no endpoints${NC}"
    exit 1
fi
echo ""

# Test 4: Health Check (Internal)
echo -e "${YELLOW}Test 4: Testing Internal Health Endpoint...${NC}"
HEALTH_RESPONSE=$(kubectl run test-health --image=curlimages/curl:latest --rm -i --restart=Never -- \
    curl -s http://bemind-api-service.default.svc.cluster.local:5002/health 2>/dev/null || echo "failed")
if [[ "$HEALTH_RESPONSE" == *"healthy"* ]]; then
    echo -e "${GREEN}✓ Health endpoint responding: $HEALTH_RESPONSE${NC}"
else
    echo -e "${RED}✗ Health endpoint not responding properly${NC}"
    echo "Response: $HEALTH_RESPONSE"
    exit 1
fi
echo ""

# Test 5: ConfigMap
echo -e "${YELLOW}Test 5: Checking ConfigMap...${NC}"
if kubectl get configmap bemind-config -n default > /dev/null 2>&1; then
    echo -e "${GREEN}✓ ConfigMap exists${NC}"
    LOG_LEVEL=$(kubectl get configmap bemind-config -n default -o jsonpath='{.data.LOG_LEVEL}')
    echo "  LOG_LEVEL: $LOG_LEVEL"
else
    echo -e "${RED}✗ ConfigMap not found${NC}"
    exit 1
fi
echo ""

# Test 6: Secrets
echo -e "${YELLOW}Test 6: Checking Secrets...${NC}"
if kubectl get secret bemind-secrets -n default > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Secrets exist${NC}"
    SECRET_KEYS=$(kubectl get secret bemind-secrets -n default -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null | wc -l)
    echo "  Number of secret keys: $SECRET_KEYS"
else
    echo -e "${RED}✗ Secrets not found${NC}"
    exit 1
fi
echo ""

# Test 7: HPA
echo -e "${YELLOW}Test 7: Checking HPA...${NC}"
if kubectl get hpa bemind-api-hpa -n default > /dev/null 2>&1; then
    echo -e "${GREEN}✓ HPA exists${NC}"
    kubectl get hpa bemind-api-hpa -n default
else
    echo -e "${YELLOW}⚠ HPA not found (optional)${NC}"
fi
echo ""

# Test 8: Application Logs
echo -e "${YELLOW}Test 8: Checking Application Logs...${NC}"
POD_NAME=$(kubectl get pods -n default -l app=bemind-api -o jsonpath='{.items[0].metadata.name}')
ERROR_COUNT=$(kubectl logs -n default $POD_NAME --tail=100 | grep -i "error" | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ No errors in recent logs${NC}"
else
    echo -e "${YELLOW}⚠ Found $ERROR_COUNT error messages in logs${NC}"
    echo "Recent errors:"
    kubectl logs -n default $POD_NAME --tail=100 | grep -i "error" | tail -5
fi
echo ""

# Test 9: Resource Usage
echo -e "${YELLOW}Test 9: Checking Resource Usage...${NC}"
if kubectl top pods -n default -l app=bemind-api > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Resource metrics available${NC}"
    kubectl top pods -n default -l app=bemind-api
else
    echo -e "${YELLOW}⚠ Resource metrics not available (metrics-server may not be installed)${NC}"
fi
echo ""

# Test 10: Port Forward Test
echo -e "${YELLOW}Test 10: Testing Port Forward Access...${NC}"
echo "Starting port-forward in background..."
kubectl port-forward svc/bemind-api-service 8080:5002 -n default > /dev/null 2>&1 &
PF_PID=$!
sleep 3

if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Port-forward access working${NC}"
    RESPONSE=$(curl -s http://localhost:8080/health)
    echo "  Response: $RESPONSE"
else
    echo -e "${YELLOW}⚠ Port-forward test skipped or failed${NC}"
fi

kill $PF_PID 2>/dev/null || true
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All Tests Completed!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo "Summary:"
echo "  - Pods: Running"
echo "  - Deployment: Ready"
echo "  - Service: Active"
echo "  - Health Checks: Passing"
echo "  - Configuration: Valid"

echo ""
echo "Next steps:"
echo "  1. Monitor logs: kubectl logs -n default -l app=bemind-api --follow"
echo "  2. Access API: kubectl port-forward svc/bemind-api-service 8080:5002 -n default"
echo "  3. Test endpoints: curl http://localhost:8080/health"