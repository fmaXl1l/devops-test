# DevOps Microservice

FastAPI microservice with JWT authentication and API key validation deployed on Azure with APIM.

## Evaluation

**HOST**: `52.179.113.219:8000`

### Generate JWT Token
```bash
curl -X POST http://52.179.113.219:8000/generate-token
```

### Test API (Evaluation Command)
```bash
JWT=$(curl -s -X POST "http://52.179.113.219:8000/generate-token" | jq -r '.jwt')

curl -X POST \
-H "X-Parse-REST-API-Key: 2f5ae96c-b558-4c7b-a590-a501ae1c3f6c" \
-H "X-JWT-KWY: ${JWT}" \
-H "Content-Type: application/json" \
-d '{ "message" : "This is a test", "to": "Juan Perez", "from": "Rita Asturia", "timeToLifeSec" : 45 }' \
http://52.179.113.219:8000/DevOps
```

**Expected Response:**
```json
{"message":"Hello Juan Perez your message will be send"}
```

## Quick Testing

```bash
# Run end-to-end tests
./scripts/public-e2e-test.sh

# Test evaluation command
./scripts/final-apim-test.sh
```

## URLs

- **API**: http://52.179.113.219:8000
- **APIM**: https://devops-microservice-dev-apim.azure-api.net
- **Health**: http://52.179.113.219:8000/health

## Features Implemented

✅ **Azure API Management** - JWT generation and API gateway  
✅ **JWT Authentication** - Unique token per transaction  
✅ **API Key Validation** - X-Parse-REST-API-Key header  
✅ **Azure Infrastructure** - AKS, ACR, APIM, VNet via Terraform  
✅ **CI/CD Pipeline** - GitHub Actions workflows  
✅ **Load Balancing** - Multiple pods with external IP  

## Architecture

- **API Gateway**: Azure API Management (APIM)
- **Application**: FastAPI on Azure Kubernetes Service (AKS)
- **Registry**: Azure Container Registry (ACR)
- **Infrastructure**: Terraform with Azure backend
- **CI/CD**: GitHub Actions