param acrSku string
param clusterName string
param existingAcrName string
param location string
param isGovCloudDeployment bool
param useExistingAcr bool

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = if (!useExistingAcr) {
  name: clusterName
  location: location
  sku: {
    name: acrSku
  }
}

resource acrExisting 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = if (useExistingAcr && !(empty(existingAcrName))){
  name: existingAcrName
}

var name = useExistingAcr ? existingAcrName : clusterName

output endpoint string = isGovCloudDeployment ? '${name}.azurecr.us/' : '${name}.azurecr.io/'
output acrName string = name
