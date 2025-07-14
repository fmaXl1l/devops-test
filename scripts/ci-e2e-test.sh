#!/bin/bash

# CI/CD End-to-End Testing Script
# Optimized for GitHub Actions environment

set -e

# Configuration for CI environment
API_KEY="2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"
NAMESPACE="devops-microservice"
SERVICE_NAME="devops-microservice-service"
MAX_WAIT_TIME=300  # 5 minutes
TEST_TIMEOUT=30    # 30 seconds per test

# Colors for output (if supported)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Test result function
test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✅ PASS${NC} - $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ FAIL${NC} - $test_name"
        echo -e "   ${RED}Details:${NC} $details"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Wait for deployment to be ready
wait_for_deployment() {
    log "Waiting for deployment to be ready..."
    
    if kubectl wait --for=condition=available deployment/devops-microservice -n $NAMESPACE --timeout=${MAX_WAIT_TIME}s; then
        log "Deployment is ready"
        return 0
    else
        log "Deployment failed to become ready within $MAX_WAIT_TIME seconds"
        return 1
    fi
}

# Setup port forwarding with proper cleanup
setup_port_forward() {
    log "Setting up port forwarding..."
    
    # Kill any existing port forwards
    pkill -f "kubectl port-forward.*$SERVICE_NAME" 2>/dev/null || true
    sleep 2
    
    # Start port forwarding in background
    kubectl port-forward svc/$SERVICE_NAME 8080:8000 -n $NAMESPACE &
    PF_PID=$!
    
    # Wait for port forward to be ready
    for i in {1..30}; do
        if curl -s --max-time 5 http://localhost:8080/health &>/dev/null; then
            log "Port forward ready"
            return 0
        fi
        sleep 1
    done
    
    log "Port forward failed to establish"
    return 1
}

# Cleanup function
cleanup() {
    log "Cleaning up..."
    if [[ -n "${PF_PID:-}" ]]; then
        kill $PF_PID 2>/dev/null || true
    fi
    pkill -f "kubectl port-forward.*$SERVICE_NAME" 2>/dev/null || true
}

trap cleanup EXIT

# Quick health check
test_health() {
    log "Testing health endpoint..."
    
    local response=$(curl -s -w "%{http_code}" --max-time $TEST_TIMEOUT -o /dev/null http://localhost:8080/health)
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        test_result "Health Check" "PASS" "Service is healthy"
    else
        test_result "Health Check" "FAIL" "HTTP $http_code"
    fi
}

# Test JWT generation
test_jwt() {
    log "Testing JWT generation..."
    
    local response=$(curl -s -w "%{http_code}" --max-time $TEST_TIMEOUT -X POST -o /tmp/jwt.json http://localhost:8080/generate-token)
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        JWT_TOKEN=$(jq -r '.jwt' /tmp/jwt.json 2>/dev/null || echo "")
        if [[ -n "$JWT_TOKEN" && "$JWT_TOKEN" != "null" ]]; then
            test_result "JWT Generation" "PASS" "Token generated successfully"
        else
            test_result "JWT Generation" "FAIL" "Token not found in response"
        fi
    else
        test_result "JWT Generation" "FAIL" "HTTP $http_code"
    fi
}

# Test DevOps endpoint
test_devops() {
    log "Testing DevOps endpoint..."
    
    local payload='{"message": "CI Test", "to": "DevOps Team", "from": "CI Runner", "timeToLifeSec": 60}'
    
    local response=$(curl -s -w "%{http_code}" --max-time $TEST_TIMEOUT -X POST \
        -H "Content-Type: application/json" \
        -H "X-Parse-REST-API-Key: $API_KEY" \
        -H "X-JWT-KWY: $JWT_TOKEN" \
        -d "$payload" \
        -o /tmp/devops.json \
        http://localhost:8080/DevOps)
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        test_result "DevOps Endpoint" "PASS" "Request processed successfully"
    else
        test_result "DevOps Endpoint" "FAIL" "HTTP $http_code"
    fi
}

# Test authentication
test_auth() {
    log "Testing authentication..."
    
    local payload='{"message": "Auth Test", "to": "DevOps Team", "from": "CI Runner", "timeToLifeSec": 60}'
    
    # Test without API key
    local response=$(curl -s -w "%{http_code}" --max-time $TEST_TIMEOUT -X POST \
        -H "Content-Type: application/json" \
        -H "X-JWT-KWY: $JWT_TOKEN" \
        -d "$payload" \
        -o /tmp/auth.json \
        http://localhost:8080/DevOps)
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "401" || "$http_code" == "422" ]]; then
        test_result "Authentication" "PASS" "Correctly rejected request without API key"
    else
        test_result "Authentication" "FAIL" "Expected 401/422, got HTTP $http_code"
    fi
}

# Test load handling
test_load() {
    log "Testing load handling..."
    
    local success_count=0
    local total_requests=5
    
    for i in $(seq 1 $total_requests); do
        local payload="{\"message\": \"Load test $i\", \"to\": \"DevOps Team\", \"from\": \"CI Runner\", \"timeToLifeSec\": 60}"
        
        local response=$(curl -s -w "%{http_code}" --max-time $TEST_TIMEOUT -X POST \
            -H "Content-Type: application/json" \
            -H "X-Parse-REST-API-Key: $API_KEY" \
            -H "X-JWT-KWY: $JWT_TOKEN" \
            -d "$payload" \
            -o /tmp/load_$i.json \
            http://localhost:8080/DevOps)
        
        local http_code="${response: -3}"
        
        if [[ "$http_code" == "200" ]]; then
            success_count=$((success_count + 1))
        fi
    done
    
    if [[ "$success_count" -eq "$total_requests" ]]; then
        test_result "Load Handling" "PASS" "All $total_requests requests successful"
    else
        test_result "Load Handling" "FAIL" "Only $success_count/$total_requests requests successful"
    fi
}

# Main execution
main() {
    log "Starting CI/CD End-to-End Testing"
    
    # Check if we're in CI environment
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        log "Running in GitHub Actions environment"
        export FORCE_COLOR=0  # Disable colors in CI
    fi
    
    # Prerequisites check
    for cmd in kubectl curl jq; do
        if ! command -v "$cmd" &>/dev/null; then
            log "Error: $cmd is not installed"
            exit 1
        fi
    done
    
    # Wait for deployment
    if ! wait_for_deployment; then
        log "Deployment not ready, skipping tests"
        exit 1
    fi
    
    # Setup port forwarding
    if ! setup_port_forward; then
        log "Port forwarding failed, skipping tests"
        exit 1
    fi
    
    # Run essential tests
    test_health
    test_jwt
    test_devops
    test_auth
    test_load
    
    # Summary
    log "Test Summary: $PASSED_TESTS/$TOTAL_TESTS passed"
    
    # Set GitHub Actions output
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "tests_passed=$PASSED_TESTS" >> "$GITHUB_OUTPUT"
        echo "tests_total=$TOTAL_TESTS" >> "$GITHUB_OUTPUT"
        echo "tests_failed=$FAILED_TESTS" >> "$GITHUB_OUTPUT"
    fi
    
    # Exit with appropriate code
    if [[ "$FAILED_TESTS" -eq 0 ]]; then
        log "All tests passed! 🎉"
        exit 0
    else
        log "Some tests failed"
        exit 1
    fi
}

# Run main function
main "$@"