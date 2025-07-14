# Scripts de Configuración

## configure-apim.sh

Script para configurar Azure API Management como único punto de entrada público.

### Uso

```bash
# Configurar variables de entorno
export RESOURCE_GROUP="devops-microservice-dev-rg"
export APIM_NAME="devops-microservice-dev-apim"
export AKS_CLUSTER_NAME="devops-microservice-dev-aks"

# Ejecutar script
./scripts/configure-apim.sh
```

### O usar directamente:

```bash
RESOURCE_GROUP=mi-rg APIM_NAME=mi-apim AKS_CLUSTER_NAME=mi-aks ./scripts/configure-apim.sh
```

### Funcionalidades

- ✅ **Importa API** desde AKS Service (IP interna)
- ✅ **Configura endpoints** /health, /generate-token, /DevOps
- ✅ **Valida API Key** en header X-Parse-REST-API-Key
- ✅ **Rate limiting** 100 requests/minuto por IP
- ✅ **Backend interno** apunta a ClusterIP de Kubernetes
- ✅ **CORS** habilitado para desarrollo
- ✅ **Health checks** automáticos
- ✅ **Testing** automático de endpoints

### Después de ejecutar:

1. **APIM es el único punto público** - no se necesita LoadBalancer
2. **Service cambiado a ClusterIP** - solo acceso interno
3. **URLs de acceso**:
   - Health: `https://<apim-url>/DevOps/health`
   - Token: `https://<apim-url>/DevOps/generate-token`
   - API: `https://<apim-url>/DevOps/`

### Políticas configuradas:

- **API Key validation** solo en endpoint /DevOps
- **JWT token validation** en header X-JWT-KWY
- **Rate limiting** por IP
- **Error handling** personalizado