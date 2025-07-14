# DevOps Microservice

FastAPI microservice for DevOps operations with JWT authentication and API key validation.

## Quick Start

### Environment Variables
```bash
export API_KEY="2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"
export API_URL="http://52.179.113.219:8000"
export APIM_URL="https://devops-microservice-dev-apim.azure-api.net"
```

### 1. Generate JWT Token
```bash
curl -X POST $API_URL/generate-token
```

### 2. Call DevOps Endpoint
```bash
# Get your JWT token first
JWT_TOKEN=$(curl -s -X POST $API_URL/generate-token | jq -r '.jwt')

# Call DevOps endpoint
curl -X POST $API_URL/DevOps \
  -H "Content-Type: application/json" \
  -H "X-Parse-REST-API-Key: $API_KEY" \
  -H "X-JWT-KWY: $JWT_TOKEN" \
  -d '{
    "message": "Hello DevOps!",
    "to": "DevOps Team",
    "from": "API User",
    "timeToLifeSec": 300
  }'
```

## Testing

### Run End-to-End Tests
```bash
./scripts/public-e2e-test.sh
```

### Manual Health Check
```bash
curl $API_URL/health
```

## Production URLs

- **Direct API**: http://52.179.113.219:8000
- **APIM Gateway**: https://devops-microservice-dev-apim.azure-api.net
- **Health Check**: http://52.179.113.219:8000/health

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/generate-token` | Generate JWT token |
| POST | `/DevOps` | Process DevOps message |
| GET | `/health` | Health check |

## Response Examples

### Generate Token
```json
{
  "jwt": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

### DevOps Endpoint
```json
{
  "message": "Hello DevOps Team your message will be send"
}
```