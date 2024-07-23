resource "azurerm_public_ip" "address" {
  name                = var.name
  resource_group_name = var.resourceGroupName
  location            = var.location
  allocation_method   = "Static"
  tags = {
    environment = "Production"
  }
  sku = "Standard"
}

output "PublicIpAddress" {
  value = azurerm_public_ip.address.ip_address
}

output "PublicIpName" {
  value = azurerm_public_ip.address.name
}
