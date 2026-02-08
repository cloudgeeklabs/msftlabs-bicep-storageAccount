// ============ //
// Parameters   //
// ============ //

@description('Required. The name of the storage account to configure diagnostics for.')
param storageAccountName string

@description('Required. Resource ID of the Log Analytics workspace.')
param workspaceId string

@description('Optional. The name of the diagnostic setting.')
param diagnosticSettingName string = '${storageAccountName}-diagnostics'

@description('Optional. Enable storage transaction metrics.')
param enableMetrics bool = true

// ============ //
// Variables    //
// ============ //

// Metrics configuration - captures storage account transaction metrics
var metricsConfig = [
  {
    category: 'Transaction'
    enabled: enableMetrics
    retentionPolicy: {
      enabled: false
      days: 0
    }
  }
  {
    category: 'Capacity'
    enabled: enableMetrics
    retentionPolicy: {
      enabled: false
      days: 0
    }
  }
]

// ============ //
// Resources    //
// ============ //

// Reference existing storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' existing = {
  name: storageAccountName
}

// Deploy diagnostic settings for storage account
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.insights/diagnosticsettings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingName
  scope: storageAccount
  properties: {

    workspaceId: workspaceId
    metrics: metricsConfig
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the diagnostic setting.')
output resourceId string = diagnosticSettings.id

@description('The name of the diagnostic setting.')
output name string = diagnosticSettings.name
