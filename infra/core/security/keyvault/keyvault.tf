data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resourceGroupName // Replace with your resource group name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = "standard"
  tags                            = var.tags
  enabled_for_template_deployment = true
  soft_delete_retention_days      = 7
  purge_protection_enabled        = true
  public_network_access_enabled   = false
  enable_rbac_authorization       = true
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    virtual_network_subnet_ids = ["fee0260f-1521-4a6c-bdd7-b6eb86d43d2b"]
  }
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = var.kvAccessObjectId
    key_permissions = [
      "Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import",
      "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey", "Update",
      "Verify", "WrapKey"
    ]
    secret_permissions = [
      "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
    ]
  }
}

# resource "azurerm_key_vault_secret" "spClientKeySecret" {
#   name         = "AZURE-CLIENT-SECRET"
#   value        = var.spClientSecret
#   key_vault_id = azurerm_key_vault.kv.id
# }

resource "azurerm_key_vault_secret" "tlsKey" {
  name         = "TLS-KEY"
  value        = "placeholder"
  key_vault_id = azurerm_key_vault.kv.id
}

output "keyVaultName" {
  value = azurerm_key_vault.kv.name
}

output "keyVaultId" {
  value = azurerm_key_vault.kv.id
}

output "keyVaultUri" {
  value = azurerm_key_vault.kv.vault_uri
}
