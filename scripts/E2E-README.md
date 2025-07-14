# End-to-End Testing Scripts

This directory contains scripts for comprehensive testing of the DevOps microservice.

## Scripts

### `e2e-test.sh`

Comprehensive end-to-end testing script that validates the complete functionality of the deployed DevOps microservice.

#### Features

- **Automated Testing**: Runs all tests automatically with detailed reporting
- **Port Forwarding**: Automatically sets up kubectl port forwarding to access the service
- **Comprehensive Coverage**: Tests all major endpoints and scenarios
- **Load Testing**: Validates performance under multiple concurrent requests
- **Detailed Reporting**: Generates JSON reports with test results and timestamps
- **Color-coded Output**: Clear visual feedback for test results

#### Tests Included

1. **Health Check Test**: Validates `/health` endpoint
2. **JWT Generation Test**: Tests `/generate-token` endpoint
3. **DevOps Valid Request**: Tests `/DevOps` with valid JWT and API key
4. **DevOps No API Key**: Tests authentication failure without API key
5. **DevOps Invalid JWT**: Tests authentication failure with invalid JWT
6. **HTTP Methods Test**: Tests unsupported HTTP methods return "ERROR"
7. **Load Balancing Test**: Validates multiple sequential requests
8. **Concurrent Requests Test**: Tests concurrent request handling

#### Prerequisites

- `kubectl` configured and connected to your AKS cluster
- `curl` for HTTP requests
- `jq` for JSON parsing
- `bc` for calculations
- Service deployed in the `devops-microservice` namespace

#### Usage

```bash
# Run all tests
./scripts/e2e-test.sh

# Make sure you have the required tools installed
brew install kubectl curl jq bc  # macOS
```

#### Configuration

The script uses the following default configuration:

- **API Key**: `2f5ae96c-b558-4c7b-a590-a501ae1c3f6c`
- **Namespace**: `devops-microservice`
- **Service**: `devops-microservice-service`
- **Port**: `8080` (local) -> `8000` (service)

#### Output

The script provides:

1. **Real-time Console Output**: Color-coded test results
2. **JSON Report**: Detailed test report saved to `e2e-test-report-YYYYMMDD-HHMMSS.json`
3. **Test Summary**: Pass/fail statistics and success rate

#### Example Output

```
[2024-01-15 10:30:00] Starting End-to-End Testing for DevOps Microservice
[2024-01-15 10:30:01] Setting up port forwarding to service...
[2024-01-15 10:30:02] Port forward ready!
[2024-01-15 10:30:03] Test 1: Health Check
✅ PASS - Health Check
[2024-01-15 10:30:04] Test 2: Generate JWT Token
✅ PASS - Generate JWT Token
...
═══════════════════════════════════════
           TEST SUMMARY
═══════════════════════════════════════
Total Tests: 11
Passed: 11
Failed: 0
Success Rate: 100.00%
Report saved to: e2e-test-report-20240115-103010.json
═══════════════════════════════════════
```

#### Troubleshooting

**Port Forward Issues**:
```bash
# Check if port is already in use
lsof -i :8080

# Kill existing port forwards
pkill -f "kubectl port-forward"
```

**Service Not Found**:
```bash
# Verify service exists
kubectl get service -n devops-microservice

# Check pod status
kubectl get pods -n devops-microservice
```

**Permission Issues**:
```bash
# Verify kubectl access
kubectl auth can-i get pods -n devops-microservice

# Check current context
kubectl config current-context
```

#### Customization

To customize the tests, modify the following variables in the script:

- `API_KEY`: Your API key
- `NAMESPACE`: Kubernetes namespace
- `SERVICE_NAME`: Service name
- Test payloads and expected responses

#### Integration with CI/CD

The script returns appropriate exit codes:
- `0`: All tests passed
- `1`: Some tests failed

Perfect for integration with CI/CD pipelines:

```yaml
- name: Run E2E Tests
  run: ./scripts/e2e-test.sh
```

#### Security Note

The script uses port forwarding to access the service locally. This is safe for testing but ensure you're connected to the correct cluster and namespace.