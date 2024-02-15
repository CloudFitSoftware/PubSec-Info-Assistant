param location string
param publicIpName string
param sku string

resource webappPubIp 'Microsoft.Network/publicIPAddresses@2022-01-01' =  {
  name: publicIpName
  location: location
  sku: {
    name: sku
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}
