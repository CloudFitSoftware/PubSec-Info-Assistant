param aksIdentityType string
param aksSku object
param aksVmSize string
param clusterName string
param keyVaultName string = ''
param location string

resource aks 'Microsoft.ContainerService/managedClusters@2023-05-02-preview' = {
  name: clusterName
  location: location
  sku: aksSku
  identity: {
    type: aksIdentityType
  }
  properties: {
    enableRBAC: true
    kubernetesVersion: '1.27.7'
    dnsPrefix: '${clusterName}dns'
    agentPoolProfiles: [
      {
        mode: 'System'
        name: 'agentpool'
        enableAutoScaling: false
        count: 2
        vmSize: aksVmSize
      }
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (!(empty(keyVaultName))) {
  name: keyVaultName
}

resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2019-09-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: aks.identity.tenantId
        objectId: aks.properties.identityProfile.kubeletidentity.objectId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

output aksManagedRG string = aks.properties.nodeResourceGroup
output aksPrincipalId string = aks.identity.principalId
output kubeletPrincipalId string = aks.properties.identityProfile.kubeletidentity.objectId
output aksId string = aks.id
