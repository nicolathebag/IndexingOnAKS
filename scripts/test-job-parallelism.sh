#!/bin/bash
# Test different parallelism configurations with conflict handling

EXTERNAL_IP=$(kubectl get svc bemind-api-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
API_URL="http://${EXTERNAL_IP}/api/jobs"

echo "Testing Job Parallelism Configurations"
echo "======================================="

# Clean up existing jobs first
echo -e "\nCleaning up existing test jobs..."
curl -X DELETE "$API_URL/high-parallelism-job" 2>/dev/null || true
curl -X DELETE "$API_URL/sequential-job" 2>/dev/null || true
curl -X DELETE "$API_URL/batch-processing-job" 2>/dev/null || true
sleep 3

# Test 1: High parallelism with auto-generated name
echo -e "\n1. Creating job with auto-generated unique name..."
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "parallelism": 5,
    "completions": 1,
    "backoff_limit": 3,
    "active_deadline_seconds": 1800,
    "job_type": "high-throughput",
    "env": {
      "INDEX_NAME": "test-index",
      "BATCH_SIZE": "100"
    }
  }'

# Test 2: Sequential processing with replace_existing
echo -e "\n\n2. Creating sequential job with replace option..."
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "job_name": "sequential-job-v2",
    "replace_existing": true,
    "parallelism": 1,
    "completions": 1,
    "backoff_limit": 5,
    "job_type": "sequential",
    "env": {
      "INDEX_NAME": "sequential-index"
    }
  }'

# Test 3: Batch processing with validation
echo -e "\n\n3. Creating batch job with resource limits..."
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "job_name": "batch-processing-v2",
    "parallelism": 3,
    "completions": 10,
    "backoff_limit": 2,
    "active_deadline_seconds": 3600,
    "cpu_request": "250m",
    "memory_request": "512Mi",
    "cpu_limit": "500m",
    "memory_limit": "1Gi",
    "job_type": "batch",
    "env": {
      "BATCH_INDEX": "0",
      "TOTAL_BATCHES": "10"
    }
  }'

# List all jobs
echo -e "\n\n4. Listing all jobs..."
curl "$API_URL"

# Filter by status
echo -e "\n\n5. Listing running jobs only..."
curl "$API_URL?status=running"

echo -e "\n\nTests completed!"