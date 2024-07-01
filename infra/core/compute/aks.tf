resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.clusterName
  location            = var.location
  resource_group_name = var.resourceGroupName
  sku_tier            = var.aksSkuTier
  kubernetes_version  = "1.27.7"
  dns_prefix          = "${var.clusterName}dns"

  default_node_pool {
    name       = "agentpool"
    node_count = 2
    vm_size    = var.aksSystemVmSize
  }

  identity {
    type = var.aksIdentityType
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "infoasst" {
  count                 = var.disconnectedAi ? 1 : 0
  name                  = "infoasst"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.aksUserVmSize
  node_count            = 1
}

data "azurerm_key_vault" "existing" {
  name                = var.keyVaultName
  resource_group_name = var.resourceGroupName
}

resource "azurerm_key_vault_access_policy" "policy" {
  key_vault_id = data.azurerm_key_vault.existing.id

  tenant_id = azurerm_kubernetes_cluster.aks.identity.0.tenant_id
  object_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# note: not completely sure if these values are correct quite yet
output "aksManagedRG" {
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
  description = "The auto-generated resource group for AKS cluster nodes."
}

output "aksPrincipalId" {
  value       = azurerm_kubernetes_cluster.aks.identity.0.principal_id
  description = "The Principal ID of the AKS cluster's identity."
}

output "kubeletPrincipalId" {
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0]
  description = "The Principal ID of the AKS cluster's kubelet identity."
}

output "aksId" {
  value       = azurerm_kubernetes_cluster.aks.id
  description = "The Resource ID of the AKS cluster."
}

output "kubletId" {
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  description = "The Resource ID of the AKS cluster."
}
