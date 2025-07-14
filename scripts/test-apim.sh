#!/bin/bash

# APIM Testing Script

set -e

# Configuration
API_KEY="2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"
APIM_URL="https://devops-microservice-dev-apim.azure-api.net"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

test_result() {
    if [[ "$2" == "PASS" ]]; then
        echo -e "${GREEN}✅ PASS${NC} - $1"
    else
        echo -e "${RED}❌ FAIL${NC} - $1"
        echo "   Response: $3"
    fi
}

# Test 1: Health Check
log "Testing APIM Health Check..."
HEALTH_RESPONSE=$(curl -s "$APIM_URL/DevOps/health")
if [[ "$HEALTH_RESPONSE" == *"healthy"* ]]; then
    test_result "APIM Health Check" "PASS" "$HEALTH_RESPONSE"
else
    test_result "APIM Health Check" "FAIL" "$HEALTH_RESPONSE"
fi

# Test 2: Generate Token
log "Testing APIM JWT Generation..."
JWT_RESPONSE=$(curl -s -X POST -H "Content-Length: 0" "$APIM_URL/DevOps/generate-token")
if [[ "$JWT_RESPONSE" == *"jwt"* ]]; then
    JWT_TOKEN=$(echo "$JWT_RESPONSE" | jq -r '.jwt' 2>/dev/null || echo "")
    test_result "APIM JWT Generation" "PASS" "Token generated"
else
    test_result "APIM JWT Generation" "FAIL" "$JWT_RESPONSE"
    exit 1
fi

# Test 3: DevOps Endpoint
log "Testing APIM DevOps Endpoint..."
DEVOPS_RESPONSE=$(curl -s -X POST "$APIM_URL/DevOps/" \
  -H "Content-Type: application/json" \
  -H "X-Parse-REST-API-Key: $API_KEY" \
  -H "X-JWT-KWY: $JWT_TOKEN" \
  -d '{
    "message": "Testing APIM!",
    "to": "DevOps Team",
    "from": "APIM Test",
    "timeToLifeSec": 300
  }')

if [[ "$DEVOPS_RESPONSE" == *"Hello DevOps Team"* ]]; then
    test_result "APIM DevOps Endpoint" "PASS" "$DEVOPS_RESPONSE"
else
    test_result "APIM DevOps Endpoint" "FAIL" "$DEVOPS_RESPONSE"
fi

# Test 4: Authentication Failure
log "Testing APIM Authentication Failure..."
AUTH_FAIL_RESPONSE=$(curl -s -X POST "$APIM_URL/DevOps/" \
  -H "Content-Type: application/json" \
  -H "X-JWT-KWY: $JWT_TOKEN" \
  -d '{
    "message": "Testing without API key",
    "to": "DevOps Team",
    "from": "APIM Test",
    "timeToLifeSec": 300
  }')

if [[ "$AUTH_FAIL_RESPONSE" == *"ERROR"* ]] || [[ "$AUTH_FAIL_RESPONSE" == *"Unauthorized"* ]] || [[ "$AUTH_FAIL_RESPONSE" == *"Access denied"* ]]; then
    test_result "APIM Authentication Failure" "PASS" "Correctly rejected"
else
    test_result "APIM Authentication Failure" "FAIL" "$AUTH_FAIL_RESPONSE"
fi

echo ""
log "APIM Testing Complete!"
log "APIM Gateway URL: $APIM_URL"
log "Health Check: $APIM_URL/DevOps/health"
log "Generate Token: $APIM_URL/DevOps/generate-token"
log "DevOps API: $APIM_URL/DevOps/"