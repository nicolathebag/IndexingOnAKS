#!/bin/bash
# Test different parallelism configurations

EXTERNAL_IP=$(kubectl get svc bemind-api-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
API_URL="http://${EXTERNAL_IP}/api/jobs"

echo "Testing Job Parallelism Configurations"
echo "======================================="

# Test 1: High parallelism for fast processing
echo -e "\n1. Creating job with high parallelism (5 parallel pods)..."
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "job_name": "high-parallelism-job",
    "parallelism": 5,
    "completions": 1,
    "backoff_limit": 3,
    "active_deadline_seconds": 1800,
    "env": {
      "INDEX_NAME": "test-index",
      "BATCH_SIZE": "100"
    }
  }'

# Test 2: Sequential processing (parallelism = 1)
echo -e "\n\n2. Creating sequential job (1 pod at a time)..."
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "job_name": "sequential-job",
    "parallelism": 1,
    "completions": 1,
    "backoff_limit": 5,
    "env": {
      "INDEX_NAME": "sequential-index"
    }
  }'

# Test 3: Batch processing with multiple completions
echo -e "\n\n3. Creating batch job (3 parallel, 10 completions)..."
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "job_name": "batch-processing-job",
    "parallelism": 3,
    "completions": 10,
    "backoff_limit": 2,
    "active_deadline_seconds": 3600,
    "env": {
      "BATCH_INDEX": "0",
      "TOTAL_BATCHES": "10"
    }
  }'

echo -e "\n\nJobs created. Check status with:"
echo "curl $API_URL"