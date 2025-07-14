"""Unit tests for the DevOps microservice components."""

import jwt
import pytest
from fastapi import HTTPException

from src.auth import (
    ALGORITHM,
    JWT_SECRET_KEY,
    validate_api_key,
    validate_jwt_token,
)


class TestJWTGeneration:
    """Test JWT token generation functionality."""

    def test_jwt_generation_with_valid_payload(self, valid_jwt_payload):
        """Test JWT generation with valid payload."""
        token = jwt.encode(valid_jwt_payload, JWT_SECRET_KEY, algorithm=ALGORITHM)

        assert isinstance(token, str)
        assert len(token) > 0
        assert token.count(".") == 2  # JWT has 3 parts separated by dots

    def test_jwt_contains_transaction_id(self, valid_jwt_payload):
        """Test that generated JWT contains transaction_id."""
        token = jwt.encode(valid_jwt_payload, JWT_SECRET_KEY, algorithm=ALGORITHM)
        decoded = jwt.decode(token, JWT_SECRET_KEY, algorithms=[ALGORITHM])

        assert "transaction_id" in decoded
        assert decoded["transaction_id"] == valid_jwt_payload["transaction_id"]

    def test_jwt_contains_expiration(self, valid_jwt_payload):
        """Test that generated JWT contains expiration time."""
        token = jwt.encode(valid_jwt_payload, JWT_SECRET_KEY, algorithm=ALGORITHM)
        decoded = jwt.decode(token, JWT_SECRET_KEY, algorithms=[ALGORITHM])

        assert "exp" in decoded
        assert "iat" in decoded
        assert decoded["exp"] > decoded["iat"]


class TestAPIKeyValidation:
    """Test API key validation functionality."""

    def test_valid_api_key_validation(self, valid_api_key):
        """Test validation with correct API key."""
        result = validate_api_key(valid_api_key)
        assert result == valid_api_key

    def test_invalid_api_key_validation(self, invalid_api_key):
        """Test validation with incorrect API key."""
        with pytest.raises(HTTPException) as exc_info:
            validate_api_key(invalid_api_key)

        assert exc_info.value.status_code == 401
        assert "Invalid API Key" in str(exc_info.value.detail)

    def test_none_api_key_validation(self):
        """Test validation with None API key."""
        with pytest.raises(HTTPException) as exc_info:
            validate_api_key(None)

        assert exc_info.value.status_code == 401
        assert "Invalid API Key" in str(exc_info.value.detail)


class TestJWTValidation:
    """Test JWT token validation functionality."""

    def test_valid_jwt_validation(self, valid_jwt_token):
        """Test validation with valid JWT token."""
        result = validate_jwt_token(valid_jwt_token)

        assert isinstance(result, dict)
        assert "transaction_id" in result
        assert "exp" in result
        assert "iat" in result

    def test_expired_jwt_validation(self, expired_jwt_token):
        """Test validation with expired JWT token."""
        with pytest.raises(HTTPException) as exc_info:
            validate_jwt_token(expired_jwt_token)

        assert exc_info.value.status_code == 401
        assert "JWT token expired" in str(exc_info.value.detail)

    def test_jwt_without_transaction_id_validation(self, jwt_without_transaction_id):
        """Test validation with JWT missing transaction_id."""
        with pytest.raises(HTTPException) as exc_info:
            validate_jwt_token(jwt_without_transaction_id)

        assert exc_info.value.status_code == 401
        assert "missing transaction_id" in str(exc_info.value.detail)

    def test_invalid_jwt_validation(self, invalid_jwt_token):
        """Test validation with invalid JWT token."""
        with pytest.raises(HTTPException) as exc_info:
            validate_jwt_token(invalid_jwt_token)

        assert exc_info.value.status_code == 401
        assert "Invalid JWT token" in str(exc_info.value.detail)

    def test_none_jwt_validation(self):
        """Test validation with None JWT token."""
        with pytest.raises(HTTPException) as exc_info:
            validate_jwt_token(None)

        assert exc_info.value.status_code == 401
        assert "JWT token required" in str(exc_info.value.detail)


class TestResponseFormat:
    """Test response format validation."""

    def test_devops_response_format(self):
        """Test DevOps response format."""
        from src.main import DevOpsResponse

        response = DevOpsResponse(message="Hello Juan Perez your message will be send")
        response_dict = response.model_dump()

        assert "message" in response_dict
        assert isinstance(response_dict["message"], str)
        assert response_dict["message"] == "Hello Juan Perez your message will be send"

    def test_token_response_format(self):
        """Test token response format."""
        from src.main import TokenResponse

        test_jwt = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.test"
        response = TokenResponse(jwt=test_jwt)
        response_dict = response.model_dump()

        assert "jwt" in response_dict
        assert isinstance(response_dict["jwt"], str)
        assert response_dict["jwt"] == test_jwt

    def test_devops_message_format(self, valid_devops_message):
        """Test DevOps message format validation."""
        from src.main import DevOpsMessage

        message = DevOpsMessage(**valid_devops_message)
        message_dict = message.model_dump()

        assert "message" in message_dict
        assert "to" in message_dict
        assert "from_" in message_dict  # Internal field name
        assert "timeToLifeSec" in message_dict
        assert message_dict["to"] == "Juan Perez"
        assert message_dict["from_"] == "Rita Asturia"

        # Test alias works for input
        message_with_alias = message.model_dump(by_alias=True)
        assert "from" in message_with_alias  # Alias should appear in aliased output
