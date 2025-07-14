# Resource Group outputs
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

# AKS outputs
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_host" {
  description = "Host endpoint for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config.0.host
  sensitive   = true
}

output "aks_client_certificate" {
  description = "Client certificate for AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config.0.client_certificate
  sensitive   = true
}

output "aks_client_key" {
  description = "Client key for AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config.0.client_key
  sensitive   = true
}

output "aks_cluster_ca_certificate" {
  description = "Cluster CA certificate for AKS"
  value       = azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate
  sensitive   = true
}

output "aks_kube_config" {
  description = "Raw kubeconfig for AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

# ACR outputs
output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Login server URL for ACR"
  value       = azurerm_container_registry.main.login_server
}

output "acr_admin_username" {
  description = "Admin username for ACR"
  value       = azurerm_container_registry.main.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "Admin password for ACR"
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}

# API Management outputs
output "apim_name" {
  description = "Name of the API Management service"
  value       = azurerm_api_management.main.name
}

output "apim_gateway_url" {
  description = "Gateway URL for API Management"
  value       = azurerm_api_management.main.gateway_url
}

output "apim_management_api_url" {
  description = "Management API URL for APIM"
  value       = azurerm_api_management.main.management_api_url
}

output "apim_portal_url" {
  description = "Developer portal URL for APIM"
  value       = azurerm_api_management.main.portal_url
}

output "apim_scm_url" {
  description = "SCM URL for APIM"
  value       = azurerm_api_management.main.scm_url
}

# Note: AKS uses System-Assigned Managed Identity
# Service Principal outputs removed as they are no longer needed

# Network outputs
output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "apim_subnet_id" {
  description = "ID of the APIM subnet"
  value       = azurerm_subnet.apim.id
}

# Log Analytics outputs
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

# Deployment summary
output "deployment_summary" {
  description = "Summary of deployed resources for easy reference"
  value = {
    resource_group   = azurerm_resource_group.main.name
    aks_cluster      = azurerm_kubernetes_cluster.main.name
    acr_login_server = azurerm_container_registry.main.login_server
    apim_gateway_url = azurerm_api_management.main.gateway_url
    location         = azurerm_resource_group.main.location
  }
}