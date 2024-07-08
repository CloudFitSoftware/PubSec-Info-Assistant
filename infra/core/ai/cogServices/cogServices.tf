resource "azurerm_cognitive_account" "cognitiveService" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resourceGroupName
  kind                = "CognitiveServices"
  sku_name            = var.sku["name"]
  tags                = var.tags
  public_network_access_enabled = false
  network_acls {
    default_action = "Deny"
    ip_rules = var.whitelistedIps # adding ip for allow in firewall
    virtual_network_rules  {
      subnet_id = var.virtualNetworkSubnetId
      ignore_missing_vnet_service_endpoint = false
    }
  }
}

resource "azurerm_key_vault_secret" "search_service_key" {
  name         = "ENRICHMENT-KEY"
  value        = azurerm_cognitive_account.cognitiveService.primary_access_key
  key_vault_id = var.keyVaultId
}


output "cognitiveServicerAccountName" {
  value = azurerm_cognitive_account.cognitiveService.name
}

output "cognitiveServiceID" {
  value = azurerm_cognitive_account.cognitiveService.id
}

output "cognitiveServiceEndpoint" {
  value = azurerm_cognitive_account.cognitiveService.endpoint
}

