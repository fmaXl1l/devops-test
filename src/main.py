from fastapi import FastAPI, Header, Request
from fastapi.responses import PlainTextResponse
from datetime import datetime, timedelta, timezone
import jwt
from pydantic import BaseModel, Field
import uuid
import os

from .auth import validate_api_key, validate_jwt_token

# Application configuration
app = FastAPI(
    title="DevOps Microservice", 
    version="1.0.0",
    description="A secure microservice for DevOps operations with JWT authentication"
)

# Constants
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "jwt-secret-key-default-value")
ALGORITHM = "HS256"
TOKEN_EXPIRY_HOURS = 1

class DevOpsMessage(BaseModel):
    """Request model for DevOps endpoint"""
    message: str
    to: str
    from_: str = Field(None, alias="from")
    timeToLifeSec: int

    class Config:
        json_schema_extra = {
            "example": {
                "message": "This is a test",
                "to": "Juan Perez",
                "from": "Rita Asturia",
                "timeToLifeSec": 45
            }
        }

class DevOpsResponse(BaseModel):
    """Response model for DevOps endpoint"""
    message: str

    class Config:
        json_schema_extra = {
            "example": {
                "message": "Hello Juan Perez your message will be send"
            }
        }

class TokenResponse(BaseModel):
    jwt: str


@app.post(
    "/DevOps", 
    response_model=DevOpsResponse,
    summary="Send DevOps message",
    description="Processes a DevOps message with authentication and returns a confirmation",
    responses={
        200: {
            "description": "Message processed successfully",
            "content": {
                "application/json": {
                    "example": {"message": "Hello Juan Perez your message will be send"}
                }
            }
        },
        401: {"description": "Authentication failed - Invalid API key or JWT token"}
    }
)
async def devops_endpoint(
    message: DevOpsMessage,
    api_key: str = Header(..., alias="X-Parse-REST-API-Key", description="API Key: 2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"),
    jwt_token: str = Header(..., alias="X-JWT-KWY", description="JWT token obtained from /generate-token")
):
    """
    Process a DevOps message with proper authentication.
    
    Requires:
    - Valid API key in X-Parse-REST-API-Key header
    - Valid JWT token with transaction_id in X-JWT-KWY header
    """
    validate_api_key(api_key)
    validate_jwt_token(jwt_token)
    
    return DevOpsResponse(message=f"Hello {message.to} your message will be send")

@app.post(
    "/generate-token", 
    response_model=TokenResponse,
    summary="Generate JWT token",
    description="Generates a new JWT token with unique transaction ID for authentication",
    responses={
        200: {
            "description": "JWT token generated successfully",
            "content": {
                "application/json": {
                    "example": {
                        "jwt": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
                    }
                }
            }
        }
    }
)
async def generate_token():
    """
    Generate a new JWT token with unique transaction ID.
    
    Returns a JWT token that can be used for authenticating requests to /DevOps endpoint.
    The token includes a unique transaction_id and expires in 1 hour.
    """
    transaction_id = str(uuid.uuid4())
    
    payload = {
        "transaction_id": transaction_id,
        "exp": datetime.now(timezone.utc) + timedelta(hours=TOKEN_EXPIRY_HOURS),
        "iat": datetime.now(timezone.utc)
    }
    
    token = jwt.encode(payload, JWT_SECRET_KEY, algorithm=ALGORITHM)
    
    return TokenResponse(jwt=token)


@app.get(
    "/health",
    summary="Health check endpoint",
    description="Check if the service is running and healthy"
)
async def health_check():
    """
    Health check endpoint for container health monitoring.
    Returns service status and basic information.
    """
    return {
        "status": "healthy",
        "service": "DevOps Microservice",
        "version": "1.0.0"
    }


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"])
async def catch_all(request: Request, path: str):
    return PlainTextResponse("ERROR", status_code=404)