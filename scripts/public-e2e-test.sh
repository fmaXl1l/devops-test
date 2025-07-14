#!/bin/bash

# Simple End-to-End Testing using Public IP
# For technical demonstration purposes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
API_KEY="2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"
NAMESPACE="devops-microservice"
SERVICE_NAME="devops-microservice-service"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

test_result() {
    local test_name="$1"
    local result="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✅ PASS${NC} - $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ FAIL${NC} - $test_name"
    fi
}

# Get public IP
get_public_ip() {
    log "Getting public IP address..."
    
    for i in {1..60}; do
        PUBLIC_IP=$(kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [[ -n "$PUBLIC_IP" ]]; then
            log "Public IP: $PUBLIC_IP"
            return 0
        fi
        echo "Waiting for public IP... ($i/60)"
        sleep 5
    done
    
    log "Failed to get public IP"
    return 1
}

# Test health
test_health() {
    log "Testing health endpoint..."
    
    local response=$(curl -s -w "%{http_code}" -o /dev/null http://$PUBLIC_IP:8000/health)
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        test_result "Health Check" "PASS"
    else
        test_result "Health Check" "FAIL"
    fi
}

# Test JWT generation
test_jwt() {
    log "Testing JWT generation..."
    
    local response=$(curl -s -w "%{http_code}" -X POST -o /tmp/jwt.json http://$PUBLIC_IP:8000/generate-token)
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        JWT_TOKEN=$(jq -r '.jwt' /tmp/jwt.json 2>/dev/null || echo "")
        if [[ -n "$JWT_TOKEN" ]]; then
            test_result "JWT Generation" "PASS"
        else
            test_result "JWT Generation" "FAIL"
        fi
    else
        test_result "JWT Generation" "FAIL"
    fi
}

# Test DevOps endpoint
test_devops() {
    log "Testing DevOps endpoint..."
    
    local payload='{"message": "E2E Test", "to": "DevOps Team", "from": "Test Runner", "timeToLifeSec": 60}'
    
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "X-Parse-REST-API-Key: $API_KEY" \
        -H "X-JWT-KWY: $JWT_TOKEN" \
        -d "$payload" \
        -o /tmp/devops.json \
        http://$PUBLIC_IP:8000/DevOps)
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        test_result "DevOps Endpoint" "PASS"
    else
        test_result "DevOps Endpoint" "FAIL"
    fi
}

# Test authentication failure
test_auth_failure() {
    log "Testing authentication failure..."
    
    local payload='{"message": "Auth Test", "to": "DevOps Team", "from": "Test Runner", "timeToLifeSec": 60}'
    
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "X-JWT-KWY: $JWT_TOKEN" \
        -d "$payload" \
        -o /tmp/auth_fail.json \
        http://$PUBLIC_IP:8000/DevOps)
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "401" || "$http_code" == "422" ]]; then
        test_result "Authentication Failure" "PASS"
    else
        test_result "Authentication Failure" "FAIL"
    fi
}

# Test load balancing
test_load() {
    log "Testing load balancing..."
    
    local success_count=0
    
    for i in {1..5}; do
        local payload="{\"message\": \"Load test $i\", \"to\": \"DevOps Team\", \"from\": \"Test Runner\", \"timeToLifeSec\": 60}"
        
        local response=$(curl -s -w "%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -H "X-Parse-REST-API-Key: $API_KEY" \
            -H "X-JWT-KWY: $JWT_TOKEN" \
            -d "$payload" \
            -o /tmp/load_$i.json \
            http://$PUBLIC_IP:8000/DevOps)
        
        local http_code="${response: -3}"
        
        if [[ "$http_code" == "200" ]]; then
            success_count=$((success_count + 1))
        fi
    done
    
    if [[ "$success_count" -eq 5 ]]; then
        test_result "Load Balancing" "PASS"
    else
        test_result "Load Balancing" "FAIL"
    fi
}

# Main execution
main() {
    log "Starting Public IP End-to-End Testing"
    
    # Check dependencies
    for cmd in kubectl curl jq; do
        if ! command -v "$cmd" &>/dev/null; then
            log "Error: $cmd not installed"
            exit 1
        fi
    done
    
    # Get public IP
    if ! get_public_ip; then
        log "Cannot proceed without public IP"
        exit 1
    fi
    
    # Run tests
    test_health
    test_jwt
    test_devops
    test_auth_failure
    test_load
    
    # Summary
    log "Tests completed: $PASSED_TESTS/$TOTAL_TESTS passed"
    
    if [[ "$PASSED_TESTS" -eq "$TOTAL_TESTS" ]]; then
        log "All tests passed! 🎉"
        echo "API is accessible at: http://$PUBLIC_IP:8000"
        exit 0
    else
        log "Some tests failed"
        exit 1
    fi
}

main "$@"