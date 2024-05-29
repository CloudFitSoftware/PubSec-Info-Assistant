resource "azurerm_container_registry" "acr" {
  count               = var.useExistingAcr ? 0 : 1
  name                = var.name
  resource_group_name = var.resourceGroupName
  location            = var.location
  sku                 = var.acrSku
  admin_enabled       = false
}

data "azurerm_container_registry" "acrExisting" {
  count               = var.useExistingAcr ? 1 : 0
  name                = var.acrName
  resource_group_name = var.acrResourceGroup
}

locals {
  name = var.useExistingAcr ? data.azurerm_container_registry.acrExisting[0].name : azurerm_container_registry.acr[0].name
}

output "endpoint" {
  value       = "https://${local.name}.azurecr.us"
  description = "The endpoint URL of the Azure Container Registry."
}

output "acrName" {
  value       = local.name
  description = "The name of the Azure Container Registry."
}
