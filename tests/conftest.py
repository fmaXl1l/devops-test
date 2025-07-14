"""Test configuration and fixtures for the DevOps microservice."""

import pytest
from fastapi.testclient import TestClient
from datetime import datetime, timedelta, timezone
import jwt
import uuid
import os
from unittest.mock import patch

from src.main import app
from src.auth import JWT_SECRET_KEY, ALGORITHM, API_KEY


@pytest.fixture
def client():
    """Create a test client for the FastAPI app."""
    return TestClient(app)


@pytest.fixture
def valid_api_key():
    """Return the valid API key."""
    return API_KEY


@pytest.fixture
def invalid_api_key():
    """Return an invalid API key."""
    return "invalid-api-key"


@pytest.fixture
def valid_jwt_payload():
    """Return a valid JWT payload."""
    return {
        "transaction_id": str(uuid.uuid4()),
        "exp": datetime.now(timezone.utc) + timedelta(hours=1),
        "iat": datetime.now(timezone.utc)
    }


@pytest.fixture
def valid_jwt_token(valid_jwt_payload):
    """Generate a valid JWT token."""
    return jwt.encode(valid_jwt_payload, JWT_SECRET_KEY, algorithm=ALGORITHM)


@pytest.fixture
def expired_jwt_token():
    """Generate an expired JWT token."""
    payload = {
        "transaction_id": str(uuid.uuid4()),
        "exp": datetime.now(timezone.utc) - timedelta(hours=1),  # Expired
        "iat": datetime.now(timezone.utc) - timedelta(hours=2)
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=ALGORITHM)


@pytest.fixture
def jwt_without_transaction_id():
    """Generate a JWT token without transaction_id."""
    payload = {
        "exp": datetime.now(timezone.utc) + timedelta(hours=1),
        "iat": datetime.now(timezone.utc)
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=ALGORITHM)


@pytest.fixture
def invalid_jwt_token():
    """Return an invalid JWT token."""
    return "invalid.jwt.token"


@pytest.fixture
def valid_devops_message():
    """Return a valid DevOps message payload."""
    return {
        "message": "This is a test",
        "to": "Juan Perez",
        "from": "Rita Asturia",
        "timeToLifeSec": 45
    }


@pytest.fixture
def valid_headers(valid_api_key, valid_jwt_token):
    """Return valid headers for DevOps endpoint."""
    return {
        "X-Parse-REST-API-Key": valid_api_key,
        "X-JWT-KWY": valid_jwt_token
    }


@pytest.fixture
def mock_env_vars():
    """Mock environment variables."""
    with patch.dict(os.environ, {
        "JWT_SECRET_KEY": "test-secret-key-for-testing"
    }):
        yield