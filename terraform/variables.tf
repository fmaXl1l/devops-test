variable "project_name" {
  description = "Name of the project used for resource naming"
  type        = string
  default     = "devops-microservice"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = ""
}

# AKS Configuration
variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = ""
}

variable "aks_node_count" {
  description = "Number of worker nodes in AKS cluster"
  type        = number
  default     = 2
}

variable "aks_node_vm_size" {
  description = "VM size for AKS worker nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.31.9"
}

# ACR Configuration
variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = ""
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Basic"
}

# API Management Configuration
variable "apim_name" {
  description = "Name of the API Management service"
  type        = string
  default     = ""
}

variable "apim_sku" {
  description = "SKU for API Management service"
  type        = string
  default     = "Developer"
}

variable "apim_publisher_name" {
  description = "Publisher name for API Management"
  type        = string
  default     = "DevOps Team"
}

variable "apim_publisher_email" {
  description = "Publisher email for API Management"
  type        = string
  default     = "admin@devops.local"
}

# Networking
variable "vnet_address_space" {
  description = "Address space for virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_address_prefix" {
  description = "Address prefix for AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "apim_subnet_address_prefix" {
  description = "Address prefix for APIM subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "DevOps Microservice"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}