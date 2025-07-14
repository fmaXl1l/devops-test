# DevOps Microservice

A FastAPI-based microservice for DevOps operations with token generation capabilities.

## Features

- FastAPI web framework
- JWT token generation
- DevOps endpoints
- Containerized with Docker
- Kubernetes deployment ready
- Infrastructure as Code with Terraform
- CI/CD with GitHub Actions

## Project Structure

```
src/                    # FastAPI application source code
tests/                  # pytest test suite
k8s/                    # Kubernetes manifests
terraform/              # Infrastructure as Code
.github/workflows/      # CI/CD pipelines
Dockerfile              # Container configuration
pyproject.toml          # Python project configuration
README.md              # This file
```

## Endpoints

- `GET /DevOps` - DevOps information endpoint
- `POST /generate-token` - JWT token generation endpoint

## Development

### Prerequisites

- Python 3.11+
- Docker
- Kubernetes (for deployment)
- Terraform (for infrastructure)

### Installation

```bash
# Install dependencies
pip install -e ".[dev]"

# Run the application
uvicorn src.main:app --reload

# Run tests
pytest
```

## Deployment

### Docker

```bash
# Build image
docker build -t devops-microservice .

# Run container
docker run -p 8000:8000 devops-microservice
```

### Kubernetes

```bash
# Apply manifests
kubectl apply -f k8s/
```

### Infrastructure

```bash
# Initialize Terraform
cd terraform
terraform init
terraform plan
terraform apply
```