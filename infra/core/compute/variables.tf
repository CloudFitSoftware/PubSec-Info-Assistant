variable "aksIdentityType" {
  description = "The identity type for AKS (Azure Kubernetes Service)"
  type        = string
}

variable "aksSkuTier" {
  description = "The SKU settings for AKS; Free, Standard, or Premium"
  type        = string
}

variable "aksSystemVmSize" {
  description = "The VM size for the system node pool in AKS"
  type        = string
  default     = "Standard_D16ds_v5"
}

variable "aksUserVmSize" {
  description = "The VM size for the user node pool in AKS"
  type        = string
  default     = "Standard_NC6s_v3"
}

variable "clusterName" {
  description = "The name of the AKS cluster"
  type        = string
}

variable "keyVaultName" {
  description = "The name of the Key Vault"
  type        = string
  default     = ""
}

variable "location" {
  description = "The Azure location where the resources will be deployed"
  type        = string
}

variable "resourceGroupName" {
  type    = string
  default = ""
}

variable "keyVaultId" {
  type = string
}

variable "tenantId" {
  type    = string
  default = ""
}

variable "disconnectedAi" {
  type = string
}


