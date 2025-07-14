"""Authentication and validation utilities for the DevOps microservice."""

from fastapi import HTTPException, Header
import jwt
import os

# Constants
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "jwt-secret-key-default-value")
ALGORITHM = "HS256"
API_KEY = "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"


def validate_api_key(
    x_parse_rest_api_key: str = Header(None, alias="X-Parse-REST-API-Key")
) -> str:
    """
    Validate the API key from request headers.

    Args:
        x_parse_rest_api_key: API key from X-Parse-REST-API-Key header

    Returns:
        str: The validated API key

    Raises:
        HTTPException: If API key is invalid
    """
    if x_parse_rest_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
    return x_parse_rest_api_key


def validate_jwt_token(x_jwt_kwy: str = Header(None, alias="X-JWT-KWY")) -> dict:
    """
    Validate and decode JWT token from request headers.

    Args:
        x_jwt_kwy: JWT token from X-JWT-KWY header

    Returns:
        dict: Decoded JWT payload containing transaction_id

    Raises:
        HTTPException: If JWT token is missing, invalid, expired, or missing transaction_id
    """
    if not x_jwt_kwy:
        raise HTTPException(status_code=401, detail="JWT token required")

    try:
        payload = jwt.decode(x_jwt_kwy, JWT_SECRET_KEY, algorithms=[ALGORITHM])
        if "transaction_id" not in payload:
            raise HTTPException(
                status_code=401, detail="Invalid JWT: missing transaction_id"
            )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="JWT token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid JWT token")
