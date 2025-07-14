#!/bin/bash

# Configure APIM Policies for API Key and JWT management

set -e

# Configuration
RESOURCE_GROUP="devops-microservice-dev-rg"
APIM_NAME="devops-microservice-dev-apim"
API_ID="devops-microservice-api"
API_KEY="2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

log "Configuring APIM policies for API Key and JWT management..."

# 1. Create API-level policy for header forwarding
log "Setting up API-level policy..."
cat > /tmp/api-policy.xml << 'EOF'
<policies>
    <inbound>
        <base />
        <!-- Forward all headers to backend -->
        <set-header name="X-Parse-REST-API-Key" exists-action="override">
            <value>@(context.Request.Headers.GetValueOrDefault("X-Parse-REST-API-Key", ""))</value>
        </set-header>
        <set-header name="X-JWT-KWY" exists-action="override">
            <value>@(context.Request.Headers.GetValueOrDefault("X-JWT-KWY", ""))</value>
        </set-header>
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

# Apply API-level policy
az apim api policy create \
    --service-name $APIM_NAME \
    --resource-group $RESOURCE_GROUP \
    --api-id $API_ID \
    --policy-file /tmp/api-policy.xml

log "✅ API-level policy configured"

# 2. Create operation-level policy for DevOps endpoint
log "Setting up DevOps endpoint policy..."
cat > /tmp/devops-policy.xml << 'EOF'
<policies>
    <inbound>
        <base />
        <!-- Validate API Key -->
        <choose>
            <when condition="@(context.Request.Headers.GetValueOrDefault("X-Parse-REST-API-Key", "") != "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c")">
                <return-response>
                    <set-status code="401" reason="Unauthorized" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/json</value>
                    </set-header>
                    <set-body>{"error": "Invalid API Key"}</set-body>
                </return-response>
            </when>
        </choose>
        
        <!-- Validate JWT Token -->
        <choose>
            <when condition="@(context.Request.Headers.GetValueOrDefault("X-JWT-KWY", "") == "")">
                <return-response>
                    <set-status code="401" reason="Unauthorized" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/json</value>
                    </set-header>
                    <set-body>{"error": "JWT Token required"}</set-body>
                </return-response>
            </when>
        </choose>
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

# Apply DevOps endpoint policy
az apim api operation policy create \
    --service-name $APIM_NAME \
    --resource-group $RESOURCE_GROUP \
    --api-id $API_ID \
    --operation-id devops-endpoint \
    --policy-file /tmp/devops-policy.xml

log "✅ DevOps endpoint policy configured"

# 3. Test the configuration
log "Testing APIM configuration..."

# Test health check
HEALTH_RESPONSE=$(curl -s "https://$APIM_NAME.azure-api.net/DevOps/health")
if [[ "$HEALTH_RESPONSE" == *"healthy"* ]]; then
    log "✅ Health check working"
else
    log "❌ Health check failed: $HEALTH_RESPONSE"
fi

# Test JWT generation
JWT_RESPONSE=$(curl -s -X POST -H "Content-Length: 0" "https://$APIM_NAME.azure-api.net/DevOps/generate-token")
if [[ "$JWT_RESPONSE" == *"jwt"* ]]; then
    JWT_TOKEN=$(echo "$JWT_RESPONSE" | jq -r '.jwt' 2>/dev/null)
    log "✅ JWT generation working"
else
    log "❌ JWT generation failed: $JWT_RESPONSE"
    exit 1
fi

# Test DevOps endpoint with valid credentials
DEVOPS_RESPONSE=$(curl -s -X POST "https://$APIM_NAME.azure-api.net/DevOps/" \
  -H "Content-Type: application/json" \
  -H "X-Parse-REST-API-Key: $API_KEY" \
  -H "X-JWT-KWY: $JWT_TOKEN" \
  -d '{"message": "APIM Test", "to": "DevOps Team", "from": "APIM", "timeToLifeSec": 300}')

if [[ "$DEVOPS_RESPONSE" == *"Hello DevOps Team"* ]]; then
    log "✅ DevOps endpoint working with authentication"
else
    log "❌ DevOps endpoint failed: $DEVOPS_RESPONSE"
fi

# Test DevOps endpoint without API key (should fail)
AUTH_FAIL_RESPONSE=$(curl -s -X POST "https://$APIM_NAME.azure-api.net/DevOps/" \
  -H "Content-Type: application/json" \
  -H "X-JWT-KWY: $JWT_TOKEN" \
  -d '{"message": "No API Key", "to": "DevOps Team", "from": "APIM", "timeToLifeSec": 300}')

if [[ "$AUTH_FAIL_RESPONSE" == *"Invalid API Key"* ]]; then
    log "✅ API Key validation working"
else
    log "❌ API Key validation failed: $AUTH_FAIL_RESPONSE"
fi

log "🎉 APIM configuration complete!"
log "APIM URL: https://$APIM_NAME.azure-api.net"
log "API Key and JWT are now managed by APIM"

# Cleanup
rm -f /tmp/api-policy.xml /tmp/devops-policy.xml