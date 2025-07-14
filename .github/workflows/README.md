# GitHub Actions Workflows

## Infrastructure Deployment

**Archivo**: `infrastructure.yml`

### Triggers
- Push a `main` en paths `terraform/**`
- Pull Request (solo plan)
- Manual dispatch con opción destroy

### Jobs
1. **terraform-plan** - Ejecuta plan en todos los triggers
2. **terraform-apply** - Solo en main branch
3. **terraform-destroy** - Solo manual con input destroy=true

### Secrets Requeridos
Configure estos secrets en GitHub:

```
AZURE_CREDENTIALS       - JSON con credenciales completas de Azure
                          {
                            "clientId": "xxx",
                            "clientSecret": "xxx", 
                            "subscriptionId": "xxx",
                            "tenantId": "xxx"
                          }
```

### Secrets Opcionales (Remote State)
```
TF_STATE_RESOURCE_GROUP_NAME    - Default: terraform-state-rg
TF_STATE_STORAGE_ACCOUNT_NAME   - Default: terraformstatedevops
TF_STATE_CONTAINER_NAME         - Default: tfstate
```

### Features
- ✅ Plan automático en PRs con comentarios
- ✅ Apply solo en main branch
- ✅ Manejo de errores y validación
- ✅ Outputs de infraestructura
- ✅ Configuración automática de kubectl
- ✅ Artifacts de terraform plan
- ✅ Environment protection para production

## Application CI/CD

**Archivo**: `app-deploy.yml`

### Triggers
- Push a `main` en paths `src/**`, `tests/**`, `k8s/**`
- Pull Request (solo testing)

### Stages
1. **test** - Python 3.11, pytest coverage, linting (black/ruff)
2. **security-scan** - Trivy vulnerability scanner
3. **build** - Docker build/push a ACR con tags SHA/latest
4. **deploy** - Apply manifests K8s, health checks
5. **rollback** - Automático si deploy falla

### Secrets Adicionales
```
AZURE_CREDENTIALS     - Mismo JSON que para infraestructura
ACR_LOGIN_SERVER      - URL del Azure Container Registry
AKS_CLUSTER_NAME      - Nombre del cluster AKS
RESOURCE_GROUP_NAME   - Nombre del resource group
JWT_SECRET_KEY        - Clave secreta para JWT
```

### Features
- ✅ Testing con coverage 90% mínimo
- ✅ Security scan con Trivy
- ✅ Build multi-platform Docker
- ✅ Cache de dependencies y Docker layers
- ✅ Deployment con health checks
- ✅ Rollback automático en fallos
- ✅ SBOM generation para security
- ✅ Environment protection