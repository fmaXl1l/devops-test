#!/bin/bash

# End-to-End Testing Script for DevOps Microservice
# Tests the complete functionality of the deployed API

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
API_KEY="2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"
NAMESPACE="devops-microservice"
SERVICE_NAME="devops-microservice-service"
TEMP_DIR=$(mktemp -d)
RESULTS_FILE="$TEMP_DIR/test_results.json"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Cleanup function
cleanup() {
    echo -e "${BLUE}Cleaning up...${NC}"
    rm -rf "$TEMP_DIR"
    # Kill any port-forward processes
    pkill -f "kubectl port-forward" 2>/dev/null || true
}

trap cleanup EXIT

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
    
    # Log to results file
    echo "{\"test\": \"$test_name\", \"result\": \"$result\", \"details\": \"$details\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$RESULTS_FILE"
}

# Setup port forwarding
setup_port_forward() {
    log "Setting up port forwarding to service..."
    
    # Check if service exists
    if ! kubectl get service $SERVICE_NAME -n $NAMESPACE &>/dev/null; then
        log "Service $SERVICE_NAME not found in namespace $NAMESPACE"
        exit 1
    fi
    
    # Start port forwarding
    kubectl port-forward svc/$SERVICE_NAME 8080:8000 -n $NAMESPACE &
    PF_PID=$!
    
    # Wait for port forward to be ready
    log "Waiting for port forward to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:8080/health &>/dev/null; then
            log "Port forward ready!"
            return 0
        fi
        sleep 1
    done
    
    log "Port forward failed to establish"
    exit 1
}

# Test 1: Health check
test_health_check() {
    log "Test 1: Health Check"
    
    local response=$(curl -s -w "%{http_code}" -o "$TEMP_DIR/health_response.json" http://localhost:8080/health)
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        local status=$(jq -r '.status' "$TEMP_DIR/health_response.json" 2>/dev/null || echo "")
        if [[ "$status" == "healthy" ]]; then
            test_result "Health Check" "PASS" "Service is healthy"
        else
            test_result "Health Check" "FAIL" "Status is not healthy: $status"
        fi
    else
        test_result "Health Check" "FAIL" "HTTP $http_code"
    fi
}

# Test 2: Generate JWT Token
test_generate_jwt() {
    log "Test 2: Generate JWT Token"
    
    local response=$(curl -s -w "%{http_code}" -X POST -o "$TEMP_DIR/jwt_response.json" http://localhost:8080/generate-token)
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        JWT_TOKEN=$(jq -r '.jwt' "$TEMP_DIR/jwt_response.json" 2>/dev/null || echo "")
        if [[ -n "$JWT_TOKEN" && "$JWT_TOKEN" != "null" ]]; then
            test_result "Generate JWT Token" "PASS" "JWT token generated successfully"
        else
            test_result "Generate JWT Token" "FAIL" "JWT token not found in response"
        fi
    else
        test_result "Generate JWT Token" "FAIL" "HTTP $http_code"
    fi
}

# Test 3: DevOps endpoint with valid JWT and API Key
test_devops_valid() {
    log "Test 3: DevOps Endpoint - Valid JWT and API Key"
    
    local payload='{
        "message": "Hello from E2E test",
        "to": "DevOps Team",
        "from": "Test Runner",
        "timeToLifeSec": 60
    }'
    
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "X-Parse-REST-API-Key: $API_KEY" \
        -H "X-JWT-KWY: $JWT_TOKEN" \
        -d "$payload" \
        -o "$TEMP_DIR/devops_valid_response.json" \
        http://localhost:8080/DevOps)
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        local message=$(jq -r '.message' "$TEMP_DIR/devops_valid_response.json" 2>/dev/null || echo "")
        if [[ "$message" == *"Hello DevOps Team"* ]]; then
            test_result "DevOps Valid Request" "PASS" "Message processed successfully"
        else
            test_result "DevOps Valid Request" "FAIL" "Unexpected message: $message"
        fi
    else
        test_result "DevOps Valid Request" "FAIL" "HTTP $http_code"
    fi
}

# Test 4: DevOps endpoint without API Key
test_devops_no_api_key() {
    log "Test 4: DevOps Endpoint - No API Key (should fail)"
    
    local payload='{
        "message": "Test without API key",
        "to": "DevOps Team",
        "from": "Test Runner",
        "timeToLifeSec": 60
    }'
    
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "X-JWT-KWY: $JWT_TOKEN" \
        -d "$payload" \
        -o "$TEMP_DIR/devops_no_api_response.json" \
        http://localhost:8080/DevOps)
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "401" || "$http_code" == "422" ]]; then
        test_result "DevOps No API Key" "PASS" "Correctly rejected request without API key (HTTP $http_code)"
    else
        test_result "DevOps No API Key" "FAIL" "Expected 401 or 422, got HTTP $http_code"
    fi
}

# Test 5: DevOps endpoint with invalid JWT
test_devops_invalid_jwt() {
    log "Test 5: DevOps Endpoint - Invalid JWT (should fail)"
    
    local payload='{
        "message": "Test with invalid JWT",
        "to": "DevOps Team",
        "from": "Test Runner",
        "timeToLifeSec": 60
    }'
    
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "X-Parse-REST-API-Key: $API_KEY" \
        -H "X-JWT-KWY: invalid.jwt.token" \
        -d "$payload" \
        -o "$TEMP_DIR/devops_invalid_jwt_response.json" \
        http://localhost:8080/DevOps)
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "401" ]]; then
        test_result "DevOps Invalid JWT" "PASS" "Correctly rejected request with invalid JWT"
    else
        test_result "DevOps Invalid JWT" "FAIL" "Expected 401, got HTTP $http_code"
    fi
}

# Test 6: Test different HTTP methods (should return ERROR)
test_http_methods() {
    log "Test 6: HTTP Methods - Should return ERROR"
    
    local methods=("GET" "PUT" "DELETE" "PATCH")
    
    for method in "${methods[@]}"; do
        local response=$(curl -s -w "%{http_code}" -X "$method" \
            -o "$TEMP_DIR/method_${method}_response.txt" \
            http://localhost:8080/some-random-path)
        
        local http_code="${response: -3}"
        local body=$(cat "$TEMP_DIR/method_${method}_response.txt" 2>/dev/null || echo "")
        
        if [[ "$http_code" == "404" && "$body" == "ERROR" ]]; then
            test_result "HTTP $method Method" "PASS" "Correctly returned ERROR with 404"
        else
            test_result "HTTP $method Method" "FAIL" "Expected 404 with 'ERROR', got HTTP $http_code with '$body'"
        fi
    done
}

# Test 7: Load balancing test (multiple requests)
test_load_balancing() {
    log "Test 7: Load Balancing - Multiple Requests"
    
    local success_count=0
    local total_requests=10
    
    for i in $(seq 1 $total_requests); do
        local payload='{
            "message": "Load test request '$i'",
            "to": "DevOps Team",
            "from": "Load Tester",
            "timeToLifeSec": 60
        }'
        
        local response=$(curl -s -w "%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -H "X-Parse-REST-API-Key: $API_KEY" \
            -H "X-JWT-KWY: $JWT_TOKEN" \
            -d "$payload" \
            -o "$TEMP_DIR/load_test_$i.json" \
            http://localhost:8080/DevOps)
        
        local http_code="${response: -3}"
        
        if [[ "$http_code" == "200" ]]; then
            success_count=$((success_count + 1))
        fi
        
        # Small delay between requests
        sleep 0.1
    done
    
    local success_rate=$((success_count * 100 / total_requests))
    
    if [[ "$success_rate" -ge 90 ]]; then
        test_result "Load Balancing" "PASS" "$success_count/$total_requests requests successful ($success_rate%)"
    else
        test_result "Load Balancing" "FAIL" "Only $success_count/$total_requests requests successful ($success_rate%)"
    fi
}

# Test 8: Concurrent requests test
test_concurrent_requests() {
    log "Test 8: Concurrent Requests"
    
    local concurrent_count=5
    local pids=()
    
    # Function to run concurrent request
    run_concurrent_request() {
        local id=$1
        local payload='{
            "message": "Concurrent request '$id'",
            "to": "DevOps Team",
            "from": "Concurrent Tester",
            "timeToLifeSec": 60
        }'
        
        local response=$(curl -s -w "%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -H "X-Parse-REST-API-Key: $API_KEY" \
            -H "X-JWT-KWY: $JWT_TOKEN" \
            -d "$payload" \
            -o "$TEMP_DIR/concurrent_$id.json" \
            http://localhost:8080/DevOps)
        
        local http_code="${response: -3}"
        echo "$http_code" > "$TEMP_DIR/concurrent_result_$id.txt"
    }
    
    # Start concurrent requests
    for i in $(seq 1 $concurrent_count); do
        run_concurrent_request "$i" &
        pids+=($!)
    done
    
    # Wait for all requests to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Check results
    local success_count=0
    for i in $(seq 1 $concurrent_count); do
        local result=$(cat "$TEMP_DIR/concurrent_result_$i.txt" 2>/dev/null || echo "000")
        if [[ "$result" == "200" ]]; then
            success_count=$((success_count + 1))
        fi
    done
    
    if [[ "$success_count" -eq "$concurrent_count" ]]; then
        test_result "Concurrent Requests" "PASS" "All $concurrent_count concurrent requests successful"
    else
        test_result "Concurrent Requests" "FAIL" "Only $success_count/$concurrent_count concurrent requests successful"
    fi
}

# Generate test report
generate_report() {
    log "Generating test report..."
    
    local report_file="e2e-test-report-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
    "test_summary": {
        "total_tests": $TOTAL_TESTS,
        "passed": $PASSED_TESTS,
        "failed": $FAILED_TESTS,
        "success_rate": "$(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)%",
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    },
    "test_results": [
$(cat "$RESULTS_FILE" | sed 's/$/,/' | sed '$s/,$//')
    ]
}
EOF
    
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}           TEST SUMMARY${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    echo -e "Success Rate: ${BLUE}$(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)%${NC}"
    echo -e "Report saved to: ${BLUE}$report_file${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}"
}

# Main execution
main() {
    log "Starting End-to-End Testing for DevOps Microservice"
    
    # Check dependencies
    for cmd in kubectl curl jq bc; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}Error: $cmd is not installed${NC}"
            exit 1
        fi
    done
    
    # Setup
    setup_port_forward
    
    # Run tests
    test_health_check
    test_generate_jwt
    test_devops_valid
    test_devops_no_api_key
    test_devops_invalid_jwt
    test_http_methods
    test_load_balancing
    test_concurrent_requests
    
    # Generate report
    generate_report
    
    # Return appropriate exit code
    if [[ "$FAILED_TESTS" -eq 0 ]]; then
        log "All tests passed! 🎉"
        exit 0
    else
        log "Some tests failed. Check the report for details."
        exit 1
    fi
}

# Run main function
main "$@"