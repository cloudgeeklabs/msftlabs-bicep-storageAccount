// ============ //
// Parameters   //
// ============ //

@description('Required. The name of the parent storage account.')
param storageAccountName string

@description('Optional. List of queues to create.')
param queues array = []

// ============ //
// Variables    //
// ============ //

// Determine if queue service should be deployed
var deployQueueService = !empty(queues)

// ============ //
// Resources    //
// ============ //

// Deploy Queue Service configuration
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.storage/storageaccounts-queueservices
resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2025-06-01' = if (deployQueueService) {
  name: '${storageAccountName}/default'
  properties: {}
}

// Deploy individual queues
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.storage/storageaccounts-queueservices-queues
resource storageQueues 'Microsoft.Storage/storageAccounts/queueServices/queues@2025-06-01'= [for queue in queues: if (deployQueueService) {
  parent: queueService
  name: queue.name
  properties: {
    // Optional metadata for queue organization and identification - can be used for things like cost tracking, automation, etc.
    metadata: queue.?metadata ?? {}
  }
}]

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the queue service.')
output resourceId string = deployQueueService ? queueService.id : ''

@description('The name of the queue service.')
output name string = deployQueueService ? queueService.name : ''

@description('The names of the deployed queues.')
output queueNames array = [for (queue, i) in queues: deployQueueService ? storageQueues[i].name : '']
