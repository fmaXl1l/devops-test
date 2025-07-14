# Guía Completa de Testing - DevOps Microservice

Esta guía te llevará paso a paso para probar toda la implementación DevOps que hemos creado.

## 📋 Pre-requisitos

### 1. Azure CLI configurado
```bash
# Login a Azure
az login

# Verificar subscription activa
az account show

# Si necesitas cambiar subscription
az account set --subscription "tu-subscription-id"
```

### 2. Herramientas necesarias
```bash
# Verificar herramientas instaladas
az version
terraform version
kubectl version --client
docker version
```

### 3. Permisos requeridos
- **Contributor** en la subscription de Azure
- **Owner** para crear Service Principals
- **Permisos GitHub** para configurar secrets y environments

---

## 🏗️ FASE 1: Infrastructure Testing

### Step 1: Configurar Terraform Backend (OPCIONAL)

```bash
# Solo si quieres usar remote state
az group create --name terraform-state-rg --location "East US"
az storage account create --name terraformstatedevops123 --resource-group terraform-state-rg --location "East US" --sku Standard_LRS
az storage container create --name tfstate --account-name terraformstatedevops123
```

### Step 2: Configurar variables Terraform

```bash
cd terraform

# Copiar ejemplo de variables
cp terraform.tfvars.example terraform.tfvars

# Editar variables (cambiar valores según necesidades)
nano terraform.tfvars
```

**Configurar en terraform.tfvars:**
```hcl
project_name = "devops-test"
environment  = "dev"
location     = "East US"

# Dejar vacío para auto-generación de nombres
resource_group_name = ""
aks_cluster_name    = ""
acr_name           = ""
apim_name          = ""
```

### Step 3: Deploy infraestructura

```bash
# Inicializar Terraform
terraform init

# Ver plan
terraform plan

# Aplicar (confirmar con 'yes')
terraform apply

# Verificar outputs
terraform output
```

**✅ Resultado esperado:**
```
resource_group_name = "devops-test-dev-rg"
aks_cluster_name = "devops-test-dev-aks"  
acr_login_server = "devopstestdevacr.azurecr.io"
apim_gateway_url = "https://devops-test-dev-apim.azure-api.net"
```

### Step 4: Verificar recursos creados

```bash
# Ver resource group
az group show --name devops-test-dev-rg

# Ver AKS cluster
az aks show --name devops-test-dev-aks --resource-group devops-test-dev-rg

# Ver ACR
az acr show --name devopstestdevacr

# Ver APIM
az apim show --name devops-test-dev-apim --resource-group devops-test-dev-rg
```

---

## 🚀 FASE 2: Application Testing

### Step 5: Configurar kubectl

```bash
# Obtener credenciales AKS
az aks get-credentials --resource-group devops-test-dev-rg --name devops-test-dev-aks --overwrite-existing

# Verificar conexión
kubectl cluster-info
kubectl get nodes
```

### Step 6: Deploy aplicación localmente (TESTING)

```bash
# Instalar dependencias
uv sync

# Configurar .env local para testing
echo "JWT_SECRET_KEY=test-secret-key-local" > .env

# Ejecutar tests
uv run pytest --cov=src

# Ejecutar aplicación local
uv run uvicorn src.main:app --reload --env-file .env
```

**Testing local en http://localhost:8000:**
```bash
# Test health check
curl http://localhost:8000/health

# Test generate token
curl -X POST http://localhost:8000/generate-token

# Test DevOps endpoint (debería fallar sin headers)
curl -X POST http://localhost:8000/DevOps \
  -H "Content-Type: application/json" \
  -d '{"message": "test", "to": "Juan", "from": "Rita", "timeToLifeSec": 45}'
```

### Step 7: Build y push Docker image

```bash
# Login a ACR
az acr login --name devopstestdevacr

# Build imagen
docker build -t devopstestdevacr.azurecr.io/devops-microservice:v1 .

# Push imagen
docker push devopstestdevacr.azurecr.io/devops-microservice:v1

# Verificar imagen en ACR
az acr repository list --name devopstestdevacr
```

### Step 8: Deploy a Kubernetes

```bash
# Actualizar image tag en deployment
sed -i 's|devops-microservice:latest|devopstestdevacr.azurecr.io/devops-microservice:v1|g' k8s/04-deployment.yaml

# Crear secret JWT
kubectl create secret generic devops-microservice-secret \
  --from-literal=JWT_SECRET_KEY="tu-super-secret-jwt-key-production" \
  --namespace=devops-microservice \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy todos los manifests
kubectl apply -f k8s/

# Verificar deployment
kubectl get all -n devops-microservice
kubectl logs -f deployment/devops-microservice -n devops-microservice
```

**✅ Verificaciones esperadas:**
```bash
# Pods corriendo
kubectl get pods -n devops-microservice
# NAME                                  READY   STATUS    RESTARTS   AGE
# devops-microservice-xxxxxxxxx-xxxxx   1/1     Running   0          2m

# Service con ClusterIP
kubectl get service -n devops-microservice
# NAME                          TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
# devops-microservice-service   ClusterIP   10.0.xx.xx    <none>        8000/TCP   2m

# HPA funcionando
kubectl get hpa -n devops-microservice
```

---

## 🌐 FASE 3: APIM Configuration Testing

### Step 9: Configurar APIM

```bash
# Configurar variables para script APIM
export RESOURCE_GROUP="devops-test-dev-rg"
export APIM_NAME="devops-test-dev-apim"
export AKS_CLUSTER_NAME="devops-test-dev-aks"

# Ejecutar script de configuración APIM
./scripts/configure-apim.sh
```

**✅ Resultado esperado:**
```
[SUCCESS] APIM configuration completed successfully!

API Endpoints:
  Health Check: https://devops-test-dev-apim.azure-api.net/DevOps/health
  Generate Token: https://devops-test-dev-apim.azure-api.net/DevOps/generate-token
  DevOps API: https://devops-test-dev-apim.azure-api.net/DevOps/
```

### Step 10: Testing APIM endpoints

```bash
# Obtener APIM URL
APIM_URL=$(az apim show --resource-group devops-test-dev-rg --name devops-test-dev-apim --query "gatewayUrl" --output tsv)
echo "APIM URL: $APIM_URL"

# Test 1: Health check (debe funcionar)
curl "$APIM_URL/DevOps/health"
# Esperado: {"status":"healthy","service":"DevOps Microservice","version":"1.0.0"}

# Test 2: Generate token (debe funcionar)
TOKEN_RESPONSE=$(curl -X POST "$APIM_URL/DevOps/generate-token")
echo $TOKEN_RESPONSE
# Esperado: {"jwt":"eyJ0eXAiOiJKV1Q..."}

# Extraer JWT token
JWT_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.jwt')
echo "JWT Token: $JWT_TOKEN"

# Test 3: DevOps endpoint SIN headers (debe fallar)
curl -X POST "$APIM_URL/DevOps/" \
  -H "Content-Type: application/json" \
  -d '{"message": "test", "to": "Juan", "from": "Rita", "timeToLifeSec": 45}'
# Esperado: Error 401 - Missing API key

# Test 4: DevOps endpoint CON headers (debe funcionar)
curl -X POST "$APIM_URL/DevOps/" \
  -H "Content-Type: application/json" \
  -H "X-Parse-REST-API-Key: 2f5ae96c-b558-4c7b-a590-a501ae1c3f6c" \
  -H "X-JWT-KWY: $JWT_TOKEN" \
  -d '{"message": "This is a test", "to": "Juan Perez", "from": "Rita Asturia", "timeToLifeSec": 45}'
# Esperado: {"message":"Hello Juan Perez your message will be send"}
```

---

## 🔄 FASE 4: GitHub Actions Testing

### Step 11: Configurar GitHub Secrets

En tu repositorio GitHub, ve a **Settings > Secrets and variables > Actions** y configura:

```bash
# Crear Service Principal para GitHub Actions
SP_OUTPUT=$(az ad sp create-for-rbac --name "devops-test-github-actions" --role contributor --scopes /subscriptions/$(az account show --query id --output tsv) --sdk-auth)

echo "Configura este JSON como AZURE_CREDENTIALS secret:"
echo $SP_OUTPUT
```

**Secrets requeridos:**
```
AZURE_CREDENTIALS = {JSON del comando anterior}
ACR_LOGIN_SERVER = devopstestdevacr.azurecr.io
AKS_CLUSTER_NAME = devops-test-dev-aks
RESOURCE_GROUP_NAME = devops-test-dev-rg
JWT_SECRET_KEY = tu-super-secret-jwt-key-production
```

### Step 12: Testing GitHub Actions

```bash
# Hacer cambio en código para triggear CI/CD
echo "# Test change" >> src/main.py

# Commit y push
git add .
git commit -m "test: trigger CI/CD pipeline"
git push origin main
```

**Verificar en GitHub:**
1. Ve a **Actions** tab en tu repositorio
2. Debería ejecutarse automáticamente:
   - **Infrastructure Deployment** (si cambios en terraform/)
   - **Application CI/CD** (por cambios en src/)

---

## ✅ FASE 5: End-to-End Testing

### Step 13: Testing completo del flujo

```bash
# Script de testing completo
#!/bin/bash
APIM_URL="https://tu-apim-url.azure-api.net"
API_PATH="/DevOps"

echo "=== TESTING COMPLETO ==="

# 1. Health check
echo "1. Testing health check..."
curl -f "$APIM_URL$API_PATH/health" && echo "✅ Health check OK" || echo "❌ Health check FAILED"

# 2. Generate token
echo "2. Generating token..."
TOKEN_RESPONSE=$(curl -s -X POST "$APIM_URL$API_PATH/generate-token")
JWT_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.jwt')
echo "Token generado: ${JWT_TOKEN:0:50}..."

# 3. Test autenticación
echo "3. Testing authenticated endpoint..."
RESPONSE=$(curl -s -X POST "$APIM_URL$API_PATH/" \
  -H "Content-Type: application/json" \
  -H "X-Parse-REST-API-Key: 2f5ae96c-b558-4c7b-a590-a501ae1c3f6c" \
  -H "X-JWT-KWY: $JWT_TOKEN" \
  -d '{"message": "This is a test", "to": "Juan Perez", "from": "Rita Asturia", "timeToLifeSec": 45}')

echo "Response: $RESPONSE"
if [[ $RESPONSE == *"Hello Juan Perez your message will be send"* ]]; then
    echo "✅ End-to-end test PASSED"
else
    echo "❌ End-to-end test FAILED"
fi

echo "=== TESTING COMPLETADO ==="
```

---

## 📊 Checklist Final

### ✅ Infrastructure
- [ ] Resource Group creado
- [ ] AKS cluster funcionando
- [ ] ACR registry disponible
- [ ] APIM desplegado

### ✅ Application
- [ ] Tests locales pasan (pytest)
- [ ] Docker image build exitoso
- [ ] Kubernetes deployment corriendo
- [ ] Pods healthy y ready

### ✅ APIM
- [ ] API configurada correctamente
- [ ] Health endpoint accesible
- [ ] Token generation funcionando
- [ ] API Key validation activa
- [ ] Rate limiting configurado

### ✅ CI/CD
- [ ] GitHub secrets configurados
- [ ] Infrastructure pipeline ejecuta
- [ ] Application pipeline ejecuta
- [ ] Deploy automático funciona

### ✅ End-to-End
- [ ] APIM es único punto público
- [ ] JWT generation funciona
- [ ] API Key validation funciona
- [ ] Response correcta en /DevOps endpoint

---

## 🚨 Troubleshooting

### Problemas comunes:

1. **Error de permisos Azure**: Verificar que tienes role Contributor
2. **AKS connection failed**: Ejecutar `az aks get-credentials` nuevamente
3. **ACR access denied**: Ejecutar `az acr login --name tu-acr-name`
4. **APIM timeout**: Esperar 10-15 minutos para que APIM esté completamente listo
5. **GitHub Actions fail**: Verificar todos los secrets están configurados

### Logs útiles:
```bash
# Kubernetes logs
kubectl logs -f deployment/devops-microservice -n devops-microservice

# AKS cluster info
kubectl get events -n devops-microservice --sort-by='.lastTimestamp'

# APIM logs
az apim api operation policy show --resource-group tu-rg --service-name tu-apim --api-id devops-microservice-api --operation-id devops-endpoint
```

¡Con estos pasos podrás probar completamente toda la implementación DevOps! 🚀