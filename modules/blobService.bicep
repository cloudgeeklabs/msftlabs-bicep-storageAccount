// ============ //
// Parameters   //
// ============ //

@description('Required. The name of the parent storage account.')
param storageAccountName string

@description('Optional. Delete retention policy for blobs. Protects against accidental deletion.')
param deleteRetentionPolicy object = {
  enabled: true
  days: 7
}

@description('Optional. Container delete retention policy. Allows container recovery.')
param containerDeleteRetentionPolicy object = {
  enabled: true
  days: 7
}

@description('Optional. List of blob containers to create.')
param containers array = []

// ============ //
// Variables    //
// ============ //

// Determine if blob service should be deployed based on configuration passed in! 
var deployBlobService = deleteRetentionPolicy.enabled || containerDeleteRetentionPolicy.enabled || !empty(containers)

// ============ //
// Resources    //
// ============ //

// Deploy Blob Service configuration
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.storage/storageaccounts-blobservices
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' = if (deployBlobService) {
  name: '${storageAccountName}/default'
  properties: {
    deleteRetentionPolicy: deleteRetentionPolicy
    containerDeleteRetentionPolicy: containerDeleteRetentionPolicy
  }
}

// Deploy individual blob containers
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.storage/storageaccounts-blobservices-containers
resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = [for container in containers: if (deployBlobService) {
  parent: blobService
  name: container.name
  properties: {
    // Public access level - should always be 'None' for security!!!
    publicAccess: container.?publicAccess ?? 'None'
    metadata: container.?metadata ?? {}
  }
}]

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the blob service.')
output resourceId string = deployBlobService ? blobService.id : ''

@description('The name of the blob service.')
output name string = deployBlobService ? blobService.name : ''

@description('The names of the deployed containers.')
output containerNames array = [for (container, i) in containers: deployBlobService ? blobContainers[i].name : '']
