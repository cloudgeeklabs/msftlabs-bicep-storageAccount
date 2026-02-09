// ============ //
// Parameters   //
// ============ //

@description('Required. The name of the storage account for the private endpoint.')
param storageAccountName string

@description('Required. The resource ID of the storage account.')
param storageAccountResourceId string

@description('Required. The resource ID of the subnet for the private endpoint.')
param subnetResourceId string

@description('Optional. The private link sub-resource (groupId) to connect to.')
@allowed([
  'blob'
  'file'
  'queue'
  'table'
  'web'
  'dfs'
])
param service string = 'blob'

@description('Optional. Azure region for deployment.')
param location string = resourceGroup().location

@description('Optional. The name of the private endpoint.')
param privateEndpointName string = 'pe-${storageAccountName}-${service}'

@description('Optional. Resource ID of the Private DNS Zone. If empty, DNS zone group is not created.')
param privateDnsZoneResourceId string = ''

@description('Required. Resource tags.')
param tags object

// ============ //
// Variables    //
// ============ //

// Map service group IDs to their corresponding Private DNS Zone names
// These are the standard Azure Private DNS Zone names for storage sub-resources
// Reference: https://learn.microsoft.com/azure/private-link/private-endpoint-dns
var privateDnsZoneNameMap = {
  blob: 'privatelink.blob.${az.environment().suffixes.storage}'
  file: 'privatelink.file.${az.environment().suffixes.storage}'
  queue: 'privatelink.queue.${az.environment().suffixes.storage}'
  table: 'privatelink.table.${az.environment().suffixes.storage}'
  web: 'privatelink.web.${az.environment().suffixes.storage}'
  dfs: 'privatelink.dfs.${az.environment().suffixes.storage}'
}

var privateDnsZoneName = privateDnsZoneNameMap[service]

// ============ //
// Resources    //
// ============ //

// Deploy Private Endpoint for Storage Account
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.network/privateendpoints
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: storageAccountResourceId
          groupIds: [
            service
          ]
        }
      }
    ]
  }
}

// Deploy Private DNS Zone Group for automatic DNS registration
// Only deployed when a Private DNS Zone resource ID is provided
// This enables automatic A-record registration in the Private DNS Zone
// so that the storage account FQDN resolves to the private IP address
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-05-01' = if (!empty(privateDnsZoneResourceId)) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: replace(privateDnsZoneName, '.', '-')
        properties: {
          privateDnsZoneId: privateDnsZoneResourceId
        }
      }
    ]
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the private endpoint.')
output resourceId string = privateEndpoint.id

@description('The name of the private endpoint.')
output name string = privateEndpoint.name

@description('The private link service group ID used.')
output service string = service

@description('The private IP addresses of the private endpoint.')
output customDnsConfigs array = privateEndpoint.properties.customDnsConfigs
