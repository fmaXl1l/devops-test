#!/bin/bash
set -euo pipefail

# Azure API Management Configuration Script
# This script configures APIM as the single public entry point for the DevOps microservice

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration variables
RESOURCE_GROUP="${RESOURCE_GROUP:-}"
APIM_NAME="${APIM_NAME:-}"
AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-}"
API_NAME="devops-microservice-api"
API_PATH="/DevOps"
API_DISPLAY_NAME="DevOps Microservice API"
API_DESCRIPTION="DevOps microservice API with authentication and rate limiting"
NAMESPACE="devops-microservice"
SERVICE_NAME="devops-microservice-service"

# Function to validate required variables
validate_env() {
    local missing_vars=()
    
    if [[ -z "$RESOURCE_GROUP" ]]; then
        missing_vars+=("RESOURCE_GROUP")
    fi
    
    if [[ -z "$APIM_NAME" ]]; then
        missing_vars+=("APIM_NAME")
    fi
    
    if [[ -z "$AKS_CLUSTER_NAME" ]]; then
        missing_vars+=("AKS_CLUSTER_NAME")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        printf '%s\n' "${missing_vars[@]}"
        echo
        echo "Usage:"
        echo "  RESOURCE_GROUP=<rg_name> APIM_NAME=<apim_name> AKS_CLUSTER_NAME=<aks_name> $0"
        echo
        echo "Or set them as environment variables:"
        echo "  export RESOURCE_GROUP=devops-microservice-dev-rg"
        echo "  export APIM_NAME=devops-microservice-dev-apim"
        echo "  export AKS_CLUSTER_NAME=devops-microservice-dev-aks"
        exit 1
    fi
}

# Function to get AKS credentials
configure_kubectl() {
    log_info "Configuring kubectl for AKS cluster..."
    az aks get-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$AKS_CLUSTER_NAME" \
        --overwrite-existing
    log_success "kubectl configured successfully"
}

# Function to get Kubernetes service internal IP
get_service_internal_ip() {
    log_info "Getting Kubernetes service internal IP..."
    
    # Wait for service to be ready
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        SERVICE_IP=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
        
        if [[ -n "$SERVICE_IP" && "$SERVICE_IP" != "None" ]]; then
            log_success "Service internal IP: $SERVICE_IP"
            return 0
        fi
        
        log_warning "Waiting for service to be ready... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    log_error "Failed to get service internal IP after $max_attempts attempts"
    exit 1
}

# Function to create or update API in APIM
create_api() {
    log_info "Creating API in APIM..."
    
    # Create API
    az apim api create \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --api-id "$API_NAME" \
        --path "$API_PATH" \
        --display-name "$API_DISPLAY_NAME" \
        --description "$API_DESCRIPTION" \
        --protocols https \
        --service-url "http://$SERVICE_IP:8000" \
        --subscription-required false
    
    log_success "API created successfully"
}

# Function to create API operations
create_api_operations() {
    log_info "Creating API operations..."
    
    # Health check operation
    az apim api operation create \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --api-id "$API_NAME" \
        --operation-id "health-check" \
        --display-name "Health Check" \
        --method GET \
        --url-template "/health" \
        --description "Health check endpoint"
    
    # Generate token operation
    az apim api operation create \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --api-id "$API_NAME" \
        --operation-id "generate-token" \
        --display-name "Generate Token" \
        --method POST \
        --url-template "/generate-token" \
        --description "Generate JWT token for authentication"
    
    # DevOps operation (main endpoint)
    az apim api operation create \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --api-id "$API_NAME" \
        --operation-id "devops-endpoint" \
        --display-name "DevOps Endpoint" \
        --method POST \
        --url-template "/" \
        --description "Main DevOps endpoint with API key validation"
    
    log_success "API operations created successfully"
}

# Function to create policy for API key validation
create_api_policies() {
    log_info "Creating API policies..."
    
    # Create a temporary policy file
    POLICY_FILE=$(mktemp)
    
    cat > "$POLICY_FILE" << 'EOF'
<policies>
    <inbound>
        <base />
        <!-- Rate limiting -->
        <rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
        
        <!-- API Key validation for DevOps endpoint -->
        <choose>
            <when condition="@(context.Operation.Id == "devops-endpoint")">
                <check-header name="X-Parse-REST-API-Key" failed-check-httpcode="401" failed-check-error-message="Missing or invalid API key" ignore-case="true">
                    <value>2f5ae96c-b558-4c7b-a590-a501ae1c3f6c</value>
                </check-header>
                <check-header name="X-JWT-KWY" failed-check-httpcode="401" failed-check-error-message="Missing JWT token" ignore-case="true" />
            </when>
        </choose>
        
        <!-- Set backend URL -->
        <set-backend-service base-url="http://SERVICE_IP_PLACEHOLDER:8000" />
        
        <!-- Add correlation ID -->
        <set-header name="X-Correlation-ID" exists-action="skip">
            <value>@(Guid.NewGuid().ToString())</value>
        </set-header>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
        <!-- Add CORS headers -->
        <cors allow-credentials="false">
            <allowed-origins>
                <origin>*</origin>
            </allowed-origins>
            <allowed-methods>
                <method>GET</method>
                <method>POST</method>
                <method>OPTIONS</method>
            </allowed-methods>
            <allowed-headers>
                <header>*</header>
            </allowed-headers>
        </cors>
        
        <!-- Add response headers -->
        <set-header name="X-Powered-By" exists-action="override">
            <value>Azure API Management</value>
        </set-header>
    </outbound>
    <on-error>
        <base />
        <!-- Custom error response -->
        <return-response>
            <set-status code="@(context.LastError.Source == "check-header" ? 401 : 500)" />
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>@{
                return new JObject(
                    new JProperty("error", new JObject(
                        new JProperty("code", context.Response.StatusCode),
                        new JProperty("message", context.LastError.Message),
                        new JProperty("timestamp", DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))
                    ))
                ).ToString();
            }</set-body>
        </return-response>
    </on-error>
</policies>
EOF

    # Replace placeholder with actual service IP
    sed -i "s/SERVICE_IP_PLACEHOLDER/$SERVICE_IP/g" "$POLICY_FILE"
    
    # Apply policy to API
    az apim api policy create \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --api-id "$API_NAME" \
        --policy-format xml \
        --value @"$POLICY_FILE"
    
    # Clean up
    rm "$POLICY_FILE"
    
    log_success "API policies created successfully"
}

# Function to create specific operation policies
create_operation_policies() {
    log_info "Creating operation-specific policies..."
    
    # Policy for health check (no authentication required)
    HEALTH_POLICY_FILE=$(mktemp)
    cat > "$HEALTH_POLICY_FILE" << EOF
<policies>
    <inbound>
        <base />
        <set-backend-service base-url="http://$SERVICE_IP:8000" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
EOF

    az apim api operation policy create \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --api-id "$API_NAME" \
        --operation-id "health-check" \
        --policy-format xml \
        --value @"$HEALTH_POLICY_FILE"
    
    rm "$HEALTH_POLICY_FILE"
    
    # Policy for generate-token (no authentication required)
    TOKEN_POLICY_FILE=$(mktemp)
    cat > "$TOKEN_POLICY_FILE" << EOF
<policies>
    <inbound>
        <base />
        <set-backend-service base-url="http://$SERVICE_IP:8000" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
EOF

    az apim api operation policy create \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --api-id "$API_NAME" \
        --operation-id "generate-token" \
        --policy-format xml \
        --value @"$TOKEN_POLICY_FILE"
    
    rm "$TOKEN_POLICY_FILE"
    
    log_success "Operation policies created successfully"
}

# Function to get APIM gateway URL
get_apim_gateway_url() {
    log_info "Getting APIM gateway URL..."
    
    GATEWAY_URL=$(az apim show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APIM_NAME" \
        --query "gatewayUrl" \
        --output tsv)
    
    log_success "APIM Gateway URL: $GATEWAY_URL"
    echo
    log_info "API Endpoints:"
    echo "  Health Check: $GATEWAY_URL$API_PATH/health"
    echo "  Generate Token: $GATEWAY_URL$API_PATH/generate-token"
    echo "  DevOps API: $GATEWAY_URL$API_PATH/"
    echo
}

# Function to test the API
test_api() {
    log_info "Testing API endpoints..."
    
    # Test health check
    log_info "Testing health check endpoint..."
    if curl -f -s "$GATEWAY_URL$API_PATH/health" > /dev/null; then
        log_success "Health check endpoint is working"
    else
        log_warning "Health check endpoint test failed"
    fi
    
    # Test generate token
    log_info "Testing generate token endpoint..."
    if curl -f -s -X POST "$GATEWAY_URL$API_PATH/generate-token" > /dev/null; then
        log_success "Generate token endpoint is working"
    else
        log_warning "Generate token endpoint test failed"
    fi
    
    # Test DevOps endpoint (should fail without headers)
    log_info "Testing DevOps endpoint without headers (should fail)..."
    if ! curl -f -s -X POST "$GATEWAY_URL$API_PATH/" > /dev/null 2>&1; then
        log_success "DevOps endpoint correctly requires authentication"
    else
        log_warning "DevOps endpoint should require authentication"
    fi
}

# Main execution
main() {
    echo "=================================================="
    echo "    Azure API Management Configuration Script"
    echo "=================================================="
    echo
    
    # Validate environment variables
    validate_env
    
    # Configure kubectl
    configure_kubectl
    
    # Get service internal IP
    get_service_internal_ip
    
    # Create API
    create_api
    
    # Create API operations
    create_api_operations
    
    # Create API policies
    create_api_policies
    
    # Create operation-specific policies
    create_operation_policies
    
    # Get gateway URL and display endpoints
    get_apim_gateway_url
    
    # Test the API
    test_api
    
    echo
    log_success "APIM configuration completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Update your applications to use APIM endpoints instead of LoadBalancer"
    echo "2. Change Kubernetes service type from LoadBalancer to ClusterIP"
    echo "3. Update any CI/CD pipelines to use the new APIM URLs"
    echo
}

# Execute main function
main "$@"