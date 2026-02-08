// ============ //
// Parameters   //
// ============ //

@description('Required. The name of the storage account to lock.')
param storageAccountName string

@description('Optional. The lock level to apply.')
@allowed([
  'CanNotDelete'
  'ReadOnly'
])
param lockLevel string = 'CanNotDelete'

@description('Optional. Notes describing why the lock was applied.')
param lockNotes string = 'Prevents accidental deletion of production storage account.'

// ============ //
// Resources    //
// ============ //

// Reference existing storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' existing = {
  name: storageAccountName
}

// Apply resource lock to storage account
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.authorization/locks
resource lock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: '${storageAccountName}-lock'
  scope: storageAccount
  properties: {
    level: lockLevel
    notes: lockNotes
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the lock.')
output resourceId string = lock.id

@description('The name of the lock.')
output name string = lock.name

@description('The lock level applied.')
output level string = lock.properties.level
