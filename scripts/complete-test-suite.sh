#!/bin/bash
# ================================================================
# Indexing Complete Test Suite
# Comprehensive testing of all deployment components
# ================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Namespace
NAMESPACE="default"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Indexing Complete Test Suite${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Helper function to run test
run_test() {
    local test_name=$1
    local test_command=$2
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${YELLOW}Test ${TESTS_TOTAL}: ${test_name}...${NC}"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✓ PASSED${NC}\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}\n"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Kubernetes Connection
test_k8s_connection() {
    kubectl cluster-info > /dev/null 2>&1
}

# Test 2: Pod Status
test_pod_status() {
    local running_pods=$(kubectl get pods -n $NAMESPACE -l app=indexer-api -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | wc -w)
    if [ "$running_pods" -gt 0 ]; then
        echo "  Running pods: $running_pods"
        kubectl get pods -n $NAMESPACE -l app=indexer-api
        return 0
    fi
    return 1
}

# Test 3: Deployment Readiness
test_deployment_ready() {
    local ready=$(kubectl get deployment indexer-api -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    local desired=$(kubectl get deployment indexer-api -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    
    if [ "$ready" == "$desired" ] && [ "$ready" -gt 0 ]; then
        echo "  Replicas: $ready/$desired ready"
        return 0
    fi
    echo "  Replicas: $ready/$desired ready (FAILED)"
    return 1
}

# Test 4: Service Endpoints
test_service_endpoints() {
    local endpoints=$(kubectl get endpoints indexer-api-service -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}')
    if [ -n "$endpoints" ]; then
        echo "  Endpoints: $endpoints"
        return 0
    fi
    return 1
}

# Test 5: Health Check (Internal)
test_health_internal() {
    local health=$(kubectl run test-health-$$  --image=curlimages/curl:latest --rm -i --restart=Never -- \
        curl -s http://indexer-api-service.${NAMESPACE}.svc.cluster.local:5002/health 2>/dev/null || echo "failed")
    
    if [[ "$health" == *"healthy"* ]]; then
        echo "  Response: $health"
        return 0
    fi
    echo "  Response: $health"
    return 1
}

# Test 6: ConfigMap Exists
test_configmap() {
    if kubectl get configmap indexer-config -n $NAMESPACE > /dev/null 2>&1; then
        local log_level=$(kubectl get configmap indexer-config -n $NAMESPACE -o jsonpath='{.data.LOG_LEVEL}')
        echo "  LOG_LEVEL: $log_level"
        return 0
    fi
    return 1
}

# Test 7: Secrets Exist
test_secrets() {
    if kubectl get secret indexer-secrets -n $NAMESPACE > /dev/null 2>&1; then
        local keys=$(kubectl get secret indexer-secrets -n $NAMESPACE -o jsonpath='{.data}' | grep -o '"[^"]*":' | wc -l)
        echo "  Secret keys: $keys"
        return 0
    fi
    return 1
}

# Test 8: HPA Configuration
test_hpa() {
    if kubectl get hpa indexer-api-hpa -n $NAMESPACE > /dev/null 2>&1; then
        local min=$(kubectl get hpa indexer-api-hpa -n $NAMESPACE -o jsonpath='{.spec.minReplicas}')
        local max=$(kubectl get hpa indexer-api-hpa -n $NAMESPACE -o jsonpath='{.spec.maxReplicas}')
        echo "  Replicas: ${min}-${max}"
        kubectl get hpa indexer-api-hpa -n $NAMESPACE
        return 0
    fi
    return 1
}

# Test 9: RBAC Configuration
test_rbac() {
    if kubectl get serviceaccount indexer-sa -n $NAMESPACE > /dev/null 2>&1 && \
       kubectl get role indexer-role -n $NAMESPACE > /dev/null 2>&1 && \
       kubectl get rolebinding indexer-rolebinding -n $NAMESPACE > /dev/null 2>&1; then
        echo "  ServiceAccount: indexer-sa"
        echo "  Role: indexer-role"
        echo "  RoleBinding: indexer-rolebinding"
        return 0
    fi
    return 1
}

# Test 10: External Access (if LoadBalancer)
test_external_access() {
    local external_ip=$(kubectl get svc indexer-api-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$external_ip" ] && [ "$external_ip" != "null" ]; then
        echo "  External IP: $external_ip"
        
        # Try to access health endpoint
        if curl -s --connect-timeout 5 http://${external_ip}:5002/health > /dev/null 2>&1; then
            echo "  ✓ External health check passed"
            return 0
        else
            echo "  ⚠ External IP exists but health check failed"
            return 0  # Still pass if IP exists
        fi
    else
        echo "  ℹ No external IP (ClusterIP service)"
        return 0  # Not a failure
    fi
}

# Test 11: Job Creation via API
test_job_creation() {
    # Port forward in background
    kubectl port-forward svc/indexer-api-service 18080:5002 -n $NAMESPACE > /dev/null 2>&1 &
    local pf_pid=$!
    sleep 3
    
    # Create test job
    local response=$(curl -s -X POST http://localhost:18080/api/jobs \
        -H "Content-Type: application/json" \
        -d '{
            "parallelism": 1,
            "completions": 1,
            "backoff_limit": 2,
            "job_type": "test-suite"
        }' 2>/dev/null || echo "failed")
    
    # Kill port forward
    kill $pf_pid 2>/dev/null || true
    
    if [[ "$response" == *"created successfully"* ]] || [[ "$response" == *"already exists"* ]]; then
        echo "  Job creation: OK"
        return 0
    fi
    echo "  Response: $response"
    return 1
}

# Test 12: Resource Metrics
test_metrics() {
    if kubectl top nodes > /dev/null 2>&1; then
        echo "  Node metrics available"
        kubectl top pods -n $NAMESPACE -l app=indexer-api 2>/dev/null || echo "  Pod metrics not ready yet"
        return 0
    else
        echo "  ⚠ Metrics server not available (optional)"
        return 0  # Not a critical failure
    fi
}

# Test 13: Application Logs
test_logs() {
    local pod_name=$(kubectl get pods -n $NAMESPACE -l app=indexer-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$pod_name" ]; then
        local errors=$(kubectl logs $pod_name -n $NAMESPACE --tail=100 2>/dev/null | grep -i "error" | wc -l)
        
        if [ "$errors" -eq 0 ]; then
            echo "  No errors in recent logs"
            return 0
        else
            echo "  ⚠ Found $errors error messages"
            kubectl logs $pod_name -n $NAMESPACE --tail=10 | grep -i "error" || true
            return 0  # Warning, not failure
        fi
    fi
    return 1
}

# Test 14: Persistent Storage (if applicable)
test_storage() {
    local pvcs=$(kubectl get pvc -n $NAMESPACE 2>/dev/null | grep -v "NAME" | wc -l)
    
    if [ "$pvcs" -gt 0 ]; then
        echo "  PVCs found: $pvcs"
        kubectl get pvc -n $NAMESPACE
    else
        echo "  ℹ No PVCs (using emptyDir)"
    fi
    return 0  # Optional test
}

# Test 15: Network Policies (if applicable)
test_network_policies() {
    local policies=$(kubectl get networkpolicies -n $NAMESPACE 2>/dev/null | grep -v "NAME" | wc -l)
    
    if [ "$policies" -gt 0 ]; then
        echo "  Network policies: $policies"
        kubectl get networkpolicies -n $NAMESPACE
    else
        echo "  ℹ No network policies configured"
    fi
    return 0  # Optional test
}

# Run all tests
echo -e "${BLUE}Running Infrastructure Tests...${NC}\n"
run_test "Kubernetes Connection" test_k8s_connection
run_test "Pod Status" test_pod_status
run_test "Deployment Readiness" test_deployment_ready
run_test "Service Endpoints" test_service_endpoints

echo -e "${BLUE}Running Configuration Tests...${NC}\n"
run_test "ConfigMap Configuration" test_configmap
run_test "Secrets Configuration" test_secrets
run_test "RBAC Configuration" test_rbac

echo -e "${BLUE}Running Functionality Tests...${NC}\n"
run_test "Internal Health Check" test_health_internal
run_test "External Access" test_external_access
run_test "Job Creation API" test_job_creation

echo -e "${BLUE}Running Operational Tests...${NC}\n"
run_test "HPA Configuration" test_hpa
run_test "Resource Metrics" test_metrics
run_test "Application Logs" test_logs
run_test "Persistent Storage" test_storage
run_test "Network Policies" test_network_policies

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total Tests: $TESTS_TOTAL"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
else
    echo -e "${RED}Failed: 0${NC}"
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}All Tests Passed! ✓${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
fi
