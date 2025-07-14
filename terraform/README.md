# Terraform Azure Infrastructure

Infraestructura para microservicio DevOps: AKS, ACR, APIM.

## Uso

```bash
# 1. Copiar variables
cp terraform.tfvars.example terraform.tfvars

# 2. Desplegar
terraform init
terraform plan
terraform apply
```

## Outputs
- `aks_cluster_name` - Nombre cluster AKS
- `acr_login_server` - URL registry ACR  
- `apim_gateway_url` - URL gateway APIM
- `resource_group_name` - Nombre resource group