#!/bin/bash

# Final APIM Test for Evaluation
# Tests the exact command that will be used for evaluation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

HOST="devops-microservice-dev-apim.azure-api.net"
DIRECT_API="52.179.113.219:8000"

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

echo -e "${YELLOW}==========================================${NC}"
echo -e "${YELLOW}      EVALUATION COMMAND TESTING${NC}"
echo -e "${YELLOW}==========================================${NC}"
echo ""

# Test 1: JWT Generation
log "Step 1: Generating JWT token..."
echo -e "${BLUE}Command:${NC} curl -X POST -H \"Content-Length: 0\" https://$HOST/DevOps/generate-token"

JWT_RESPONSE=$(curl -s -X POST -H "Content-Length: 0" "https://$HOST/DevOps/generate-token")
if [[ "$JWT_RESPONSE" == *"jwt"* ]]; then
    JWT=$(echo "$JWT_RESPONSE" | jq -r '.jwt')
    echo -e "${GREEN}✅ JWT Generated:${NC} ${JWT:0:50}..."
else
    echo -e "${RED}❌ JWT Generation Failed:${NC} $JWT_RESPONSE"
    echo ""
    log "Trying direct API..."
    JWT=$(curl -s -X POST "http://$DIRECT_API/generate-token" | jq -r '.jwt')
    if [[ -n "$JWT" && "$JWT" != "null" ]]; then
        echo -e "${GREEN}✅ JWT Generated (Direct):${NC} ${JWT:0:50}..."
    else
        echo -e "${RED}❌ Both methods failed${NC}"
        exit 1
    fi
fi
echo ""

# Test 2: Evaluation Command via APIM
log "Step 2: Testing evaluation command via APIM..."
echo -e "${BLUE}Command:${NC} curl -X POST https://$HOST/DevOps [with headers]"

APIM_RESPONSE=$(curl -s -X POST \
-H "X-Parse-REST-API-Key: 2f5ae96c-b558-4c7b-a590-a501ae1c3f6c" \
-H "X-JWT-KWY: $JWT" \
-H "Content-Type: application/json" \
-d '{ "message" : "This is a test", "to": "Juan Perez", "from": "Rita Asturia", "timeToLifeSec" : 45 }' \
"https://$HOST/DevOps")

if [[ "$APIM_RESPONSE" == *"Hello Juan Perez"* ]]; then
    echo -e "${GREEN}✅ APIM Success:${NC} $APIM_RESPONSE"
    APIM_WORKS=true
else
    echo -e "${RED}❌ APIM Failed:${NC} $APIM_RESPONSE"
    APIM_WORKS=false
fi
echo ""

# Test 3: Evaluation Command via Direct API (backup)
log "Step 3: Testing evaluation command via Direct API..."
echo -e "${BLUE}Command:${NC} curl -X POST http://$DIRECT_API/DevOps [with headers]"

DIRECT_RESPONSE=$(curl -s -X POST \
-H "X-Parse-REST-API-Key: 2f5ae96c-b558-4c7b-a590-a501ae1c3f6c" \
-H "X-JWT-KWY: $JWT" \
-H "Content-Type: application/json" \
-d '{ "message" : "This is a test", "to": "Juan Perez", "from": "Rita Asturia", "timeToLifeSec" : 45 }' \
"http://$DIRECT_API/DevOps")

if [[ "$DIRECT_RESPONSE" == *"Hello Juan Perez"* ]]; then
    echo -e "${GREEN}✅ Direct API Success:${NC} $DIRECT_RESPONSE"
    DIRECT_WORKS=true
else
    echo -e "${RED}❌ Direct API Failed:${NC} $DIRECT_RESPONSE"
    DIRECT_WORKS=false
fi
echo ""

# Summary and Recommendations
echo -e "${YELLOW}==========================================${NC}"
echo -e "${YELLOW}              SUMMARY${NC}"
echo -e "${YELLOW}==========================================${NC}"

if [[ "$APIM_WORKS" == true ]]; then
    echo -e "${GREEN}✅ PRIMARY: APIM is working correctly${NC}"
    echo -e "${BLUE}HOST for evaluation:${NC} $HOST"
    echo -e "${BLUE}Full command:${NC}"
    echo "JWT=\$(curl -s -X POST -H \"Content-Length: 0\" \"https://$HOST/DevOps/generate-token\" | jq -r '.jwt')"
    echo ""
    echo "curl -X POST \\"
    echo "-H \"X-Parse-REST-API-Key: 2f5ae96c-b558-4c7b-a590-a501ae1c3f6c\" \\"
    echo "-H \"X-JWT-KWY: \${JWT}\" \\"
    echo "-H \"Content-Type: application/json\" \\"
    echo "-d '{ \"message\" : \"This is a test\", \"to\": \"Juan Perez\", \"from\": \"Rita Asturia\", \"timeToLifeSec\" : 45 }' \\"
    echo "https://$HOST/DevOps"
elif [[ "$DIRECT_WORKS" == true ]]; then
    echo -e "${YELLOW}⚠️  BACKUP: Direct API is working${NC}"
    echo -e "${BLUE}HOST for evaluation:${NC} $DIRECT_API"
    echo -e "${BLUE}Full command:${NC}"
    echo "JWT=\$(curl -s -X POST \"http://$DIRECT_API/generate-token\" | jq -r '.jwt')"
    echo ""
    echo "curl -X POST \\"
    echo "-H \"X-Parse-REST-API-Key: 2f5ae96c-b558-4c7b-a590-a501ae1c3f6c\" \\"
    echo "-H \"X-JWT-KWY: \${JWT}\" \\"
    echo "-H \"Content-Type: application/json\" \\"
    echo "-d '{ \"message\" : \"This is a test\", \"to\": \"Juan Perez\", \"from\": \"Rita Asturia\", \"timeToLifeSec\" : 45 }' \\"
    echo "http://$DIRECT_API/DevOps"
else
    echo -e "${RED}❌ CRITICAL: Neither APIM nor Direct API is working${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Ready for evaluation!${NC}"