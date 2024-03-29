param acrSku string
param clusterName string
param location string
param isGovCloudDeployment bool

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: clusterName
  location: location
  sku: {
    name: acrSku
  }
}

output endpoint string = isGovCloudDeployment ? '${clusterName}.azurecr.us/' : '${clusterName}.azurecr.io/'
output acrName string = clusterName
