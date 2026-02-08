// ============ //
// Parameters   //
// ============ //

@description('Required. The name of the parent storage account.')
param storageAccountName string

@description('Optional. List of tables to create.')
param tables array = []

// ============ //
// Variables    //
// ============ //

// Determine if table service should be deployed
var deployTableService = !empty(tables)

// ============ //
// Resources    //
// ============ //

// Deploy Table Service configuration
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.storage/storageaccounts-tableservices
resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2025-06-01' = if (deployTableService) {
  name: '${storageAccountName}/default'
  properties: {
    // Table service properties can be extended here for CORS, logging, etc.
  }
}

// Deploy individual tables
// API Version: 2025-06-01 (latest stable as of Feb 2026)
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.storage/storageaccounts-tableservices-tables
resource storageTables 'Microsoft.Storage/storageAccounts/tableServices/tables@2025-06-01' = [for table in tables: if (deployTableService) {
  parent: tableService
  name: table.name
  properties: {}
}]

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the table service.')
output resourceId string = deployTableService ? tableService.id : ''

@description('The name of the table service.')
output name string = deployTableService ? tableService.name : ''

@description('The names of the deployed tables.')
output tableNames array = [for (table, i) in tables: deployTableService ? storageTables[i].name : '']
