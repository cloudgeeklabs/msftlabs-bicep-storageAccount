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

@description('Optional. Enable diagnostic settings for Blob service. Should be true when blob containers are deployed.')
param enableBlobDiagnostics bool = false

@description('Optional. Enable diagnostic settings for Queue service. Should be true when queues are deployed.')
param enableQueueDiagnostics bool = false

@description('Optional. Enable diagnostic settings for Table service. Should be true when tables are deployed.')
param enableTableDiagnostics bool = false

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

// Metrics configuration for child services (Capacity category not available on child services)
var serviceMetricsConfig = [
  {
    category: 'Transaction'
    enabled: enableMetrics
    retentionPolicy: {
      enabled: false
      days: 0
    }
  }
]

// Log categories available on blob, file, queue, and table services
var serviceLogsConfig = [
  {
    category: 'StorageRead'
    enabled: true
    retentionPolicy: {
      enabled: false
      days: 0
    }
  }
  {
    category: 'StorageWrite'
    enabled: true
    retentionPolicy: {
      enabled: false
      days: 0
    }
  }
  {
    category: 'StorageDelete'
    enabled: true
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

// Reference existing child services (only when diagnostics are enabled for them)
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' existing = if (enableBlobDiagnostics) {
  name: 'default'
  parent: storageAccount
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2025-06-01' existing = if (enableQueueDiagnostics) {
  name: 'default'
  parent: storageAccount
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2025-06-01' existing = if (enableTableDiagnostics) {
  name: 'default'
  parent: storageAccount
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

// Deploy diagnostic settings for Blob service
// Only deployed when blob containers are configured
resource blobDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableBlobDiagnostics) {
  name: '${diagnosticSettingName}-blob'
  scope: blobService
  properties: {
    workspaceId: workspaceId
    metrics: serviceMetricsConfig
    logs: serviceLogsConfig
  }
}

// Deploy diagnostic settings for Queue service
// Only deployed when queues are configured
resource queueDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableQueueDiagnostics) {
  name: '${diagnosticSettingName}-queue'
  scope: queueService
  properties: {
    workspaceId: workspaceId
    metrics: serviceMetricsConfig
    logs: serviceLogsConfig
  }
}

// Deploy diagnostic settings for Table service
// Only deployed when tables are configured
resource tableDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableTableDiagnostics) {
  name: '${diagnosticSettingName}-table'
  scope: tableService
  properties: {
    workspaceId: workspaceId
    metrics: serviceMetricsConfig
    logs: serviceLogsConfig
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the storage account diagnostic setting.')
output resourceId string = diagnosticSettings.id

@description('The name of the storage account diagnostic setting.')
output name string = diagnosticSettings.name

@description('The resource ID of the blob diagnostic setting.')
output blobDiagnosticResourceId string = enableBlobDiagnostics ? blobDiagnosticSettings.id : ''

@description('The resource ID of the queue diagnostic setting.')
output queueDiagnosticResourceId string = enableQueueDiagnostics ? queueDiagnosticSettings.id : ''

@description('The resource ID of the table diagnostic setting.')
output tableDiagnosticResourceId string = enableTableDiagnostics ? tableDiagnosticSettings.id : ''
