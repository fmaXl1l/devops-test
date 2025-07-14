"""Integration tests for the DevOps microservice endpoints."""



class TestGenerateTokenEndpoint:
    """Test the /generate-token endpoint."""

    def test_generate_token_success(self, client):
        """Test successful token generation."""
        response = client.post("/generate-token")

        assert response.status_code == 200
        data = response.json()
        assert "jwt" in data
        assert isinstance(data["jwt"], str)
        assert len(data["jwt"]) > 0
        assert data["jwt"].count(".") == 2  # Valid JWT format

    def test_generate_token_response_format(self, client):
        """Test token generation response format."""
        response = client.post("/generate-token")

        assert response.status_code == 200
        data = response.json()

        # Should only contain jwt field
        assert list(data.keys()) == ["jwt"]
        assert isinstance(data["jwt"], str)

    def test_generate_token_multiple_calls_unique(self, client):
        """Test that multiple calls generate different tokens."""
        response1 = client.post("/generate-token")
        response2 = client.post("/generate-token")

        assert response1.status_code == 200
        assert response2.status_code == 200

        token1 = response1.json()["jwt"]
        token2 = response2.json()["jwt"]

        assert token1 != token2  # Tokens should be unique


class TestDevOpsEndpoint:
    """Test the /DevOps endpoint."""

    def test_devops_endpoint_success(self, client, valid_headers, valid_devops_message):
        """Test successful DevOps endpoint call."""
        response = client.post(
            "/DevOps", json=valid_devops_message, headers=valid_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert data["message"] == "Hello Juan Perez your message will be send"

    def test_devops_endpoint_missing_api_key(
        self, client, valid_jwt_token, valid_devops_message
    ):
        """Test DevOps endpoint without API key."""
        headers = {"X-JWT-KWY": valid_jwt_token}
        response = client.post("/DevOps", json=valid_devops_message, headers=headers)

        assert response.status_code == 422  # Missing required header

    def test_devops_endpoint_invalid_api_key(
        self, client, valid_jwt_token, valid_devops_message, invalid_api_key
    ):
        """Test DevOps endpoint with invalid API key."""
        headers = {
            "X-Parse-REST-API-Key": invalid_api_key,
            "X-JWT-KWY": valid_jwt_token,
        }
        response = client.post("/DevOps", json=valid_devops_message, headers=headers)

        assert response.status_code == 401
        data = response.json()
        assert "Invalid API Key" in data["detail"]

    def test_devops_endpoint_missing_jwt(
        self, client, valid_api_key, valid_devops_message
    ):
        """Test DevOps endpoint without JWT token."""
        headers = {"X-Parse-REST-API-Key": valid_api_key}
        response = client.post("/DevOps", json=valid_devops_message, headers=headers)

        assert response.status_code == 422  # Missing required header

    def test_devops_endpoint_invalid_jwt(
        self, client, valid_api_key, valid_devops_message, invalid_jwt_token
    ):
        """Test DevOps endpoint with invalid JWT token."""
        headers = {
            "X-Parse-REST-API-Key": valid_api_key,
            "X-JWT-KWY": invalid_jwt_token,
        }
        response = client.post("/DevOps", json=valid_devops_message, headers=headers)

        assert response.status_code == 401
        data = response.json()
        assert "Invalid JWT token" in data["detail"]

    def test_devops_endpoint_expired_jwt(
        self, client, valid_api_key, valid_devops_message, expired_jwt_token
    ):
        """Test DevOps endpoint with expired JWT token."""
        headers = {
            "X-Parse-REST-API-Key": valid_api_key,
            "X-JWT-KWY": expired_jwt_token,
        }
        response = client.post("/DevOps", json=valid_devops_message, headers=headers)

        assert response.status_code == 401
        data = response.json()
        assert "JWT token expired" in data["detail"]

    def test_devops_endpoint_jwt_without_transaction_id(
        self, client, valid_api_key, valid_devops_message, jwt_without_transaction_id
    ):
        """Test DevOps endpoint with JWT missing transaction_id."""
        headers = {
            "X-Parse-REST-API-Key": valid_api_key,
            "X-JWT-KWY": jwt_without_transaction_id,
        }
        response = client.post("/DevOps", json=valid_devops_message, headers=headers)

        assert response.status_code == 401
        data = response.json()
        assert "missing transaction_id" in data["detail"]

    def test_devops_endpoint_invalid_json(self, client, valid_headers):
        """Test DevOps endpoint with invalid JSON payload."""
        invalid_payload = {"invalid": "payload"}
        response = client.post("/DevOps", json=invalid_payload, headers=valid_headers)

        assert response.status_code == 422  # Validation error

    def test_devops_endpoint_missing_required_fields(self, client, valid_headers):
        """Test DevOps endpoint with missing required fields."""
        incomplete_payload = {"message": "test"}  # Missing required fields
        response = client.post(
            "/DevOps", json=incomplete_payload, headers=valid_headers
        )

        assert response.status_code == 422  # Validation error


class TestInvalidHTTPMethods:
    """Test invalid HTTP methods on endpoints."""

    def test_get_devops_endpoint(self, client):
        """Test GET request to /DevOps endpoint."""
        response = client.get("/DevOps")

        assert response.status_code == 404
        assert response.text == "ERROR"

    def test_put_devops_endpoint(self, client):
        """Test PUT request to /DevOps endpoint."""
        response = client.put("/DevOps")

        assert response.status_code == 404
        assert response.text == "ERROR"

    def test_delete_devops_endpoint(self, client):
        """Test DELETE request to /DevOps endpoint."""
        response = client.delete("/DevOps")

        assert response.status_code == 404
        assert response.text == "ERROR"

    def test_patch_devops_endpoint(self, client):
        """Test PATCH request to /DevOps endpoint."""
        response = client.patch("/DevOps")

        assert response.status_code == 404
        assert response.text == "ERROR"

    def test_get_generate_token_endpoint(self, client):
        """Test GET request to /generate-token endpoint."""
        response = client.get("/generate-token")

        assert response.status_code == 404
        assert response.text == "ERROR"

    def test_put_generate_token_endpoint(self, client):
        """Test PUT request to /generate-token endpoint."""
        response = client.put("/generate-token")

        assert response.status_code == 404
        assert response.text == "ERROR"

    def test_delete_generate_token_endpoint(self, client):
        """Test DELETE request to /generate-token endpoint."""
        response = client.delete("/generate-token")

        assert response.status_code == 404
        assert response.text == "ERROR"


class TestNonExistentEndpoints:
    """Test requests to non-existent endpoints."""

    def test_nonexistent_endpoint_get(self, client):
        """Test GET request to non-existent endpoint."""
        response = client.get("/nonexistent")

        assert response.status_code == 404
        assert response.text == "ERROR"

    def test_nonexistent_endpoint_post(self, client):
        """Test POST request to non-existent endpoint."""
        response = client.post("/nonexistent")

        assert response.status_code == 404
        assert response.text == "ERROR"

    def test_nonexistent_endpoint_put(self, client):
        """Test PUT request to non-existent endpoint."""
        response = client.put("/nonexistent")

        assert response.status_code == 404
        assert response.text == "ERROR"

    def test_nonexistent_endpoint_delete(self, client):
        """Test DELETE request to non-existent endpoint."""
        response = client.delete("/nonexistent")

        assert response.status_code == 404
        assert response.text == "ERROR"

    def test_deep_nonexistent_endpoint(self, client):
        """Test request to deep non-existent endpoint."""
        response = client.get("/very/deep/nonexistent/path")

        assert response.status_code == 404
        assert response.text == "ERROR"


class TestEndToEndFlow:
    """Test complete end-to-end flow."""

    def test_complete_flow_generate_token_and_use(self, client, valid_devops_message):
        """Test complete flow: generate token then use it."""
        # Step 1: Generate token
        token_response = client.post("/generate-token")
        assert token_response.status_code == 200
        jwt_token = token_response.json()["jwt"]

        # Step 2: Use token in DevOps endpoint
        headers = {
            "X-Parse-REST-API-Key": "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c",
            "X-JWT-KWY": jwt_token,
        }

        devops_response = client.post(
            "/DevOps", json=valid_devops_message, headers=headers
        )
        assert devops_response.status_code == 200

        data = devops_response.json()
        assert data["message"] == "Hello Juan Perez your message will be send"

    def test_multiple_requests_with_same_token(self, client, valid_devops_message):
        """Test multiple requests with the same valid token."""
        # Generate token once
        token_response = client.post("/generate-token")
        jwt_token = token_response.json()["jwt"]

        headers = {
            "X-Parse-REST-API-Key": "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c",
            "X-JWT-KWY": jwt_token,
        }

        # Use token multiple times
        for _ in range(3):
            response = client.post(
                "/DevOps", json=valid_devops_message, headers=headers
            )
            assert response.status_code == 200
            data = response.json()
            assert data["message"] == "Hello Juan Perez your message will be send"
