# Terraform Infrastructure

## Deploy
```bash
terraform init
terraform plan
terraform apply
```

## Resources Created
- AKS cluster
- Azure Container Registry
- API Management
- VNet + Subnets
- Network Security Groups

## Outputs
- `aks_cluster_name`
- `acr_login_server`
- `apim_gateway_url`
- `resource_group_name`