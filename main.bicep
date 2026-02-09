metadata name = 'StorageAccount Module'
metadata description = 'Deploys Azure Storage Account with required configurations!'
metadata owner = 'cloudgeeklabs'
metadata version = '1.0.0'

targetScope = 'resourceGroup'

// ============ //
// Parameters   //
// ============ //

@description('Required. Workload name used to generate resource names. Max 10 characters, lowercase letters and numbers only.')
@minLength(2)
@maxLength(10)
param workloadName string

@description('Optional. Azure region for deployment. Defaults to resource group location.')
param location string = resourceGroup().location

@description('Optional. Environment identifier (dev, test, prod). Used in naming and tagging.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Optional. Storage Account kind. StorageV2 recommended for general purpose workloads.')
@allowed([
  'Storage'
  'StorageV2'
  'BlobStorage'
  'FileStorage'
  'BlockBlobStorage'
])
param kind string = 'StorageV2'

@description('Optional. Storage SKU. Standard_GRS provides geo-redundancy for production.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'])
param skuName string = 'Standard_GRS'

@description('Optional. Access tier for blob storage. Hot tier optimized for frequent access.')
@allowed([
  'Hot'
  'Cool'
  'Premium'
])
param accessTier string = 'Hot'

@description('Optional. Enable OAuth as default authentication. Recommended for security.')
param defaultToOAuthAuthentication bool = true

@description('Optional. Allow shared key access. Set false to enforce Azure AD only.')
param allowSharedKeyAccess bool = false

@description('Optional. Allow anonymous blob access. Should be false for security.')
param allowBlobPublicAccess bool = false

@description('Optional. Blob service configuration including containers and retention policies.')
param blobConfig blobConfigType = {}

@description('Optional. Queue service configuration including queue definitions.')
param queueConfig queueConfigType = {}

@description('Optional. Table service configuration including table definitions.')
param tableConfig tableConfigType = {}

@description('Optional. Log Analytics workspace ID for diagnostics. Uses default if not specified.')
param diagnosticWorkspaceId string = ''

@description('Optional. Enable diagnostic settings for metrics collection.')
param enableDiagnostics bool = true

@description('Optional. Enable resource lock to prevent deletion.')
param enableLock bool = true

@description('Optional. Lock level to apply if enabled.')
@allowed([
  'CanNotDelete'
  'ReadOnly'
])
param lockLevel string = 'CanNotDelete'

@description('Optional. RBAC role assignments for the storage account.')
param roleAssignments roleAssignmentType[] = []

@description('Optional. Private endpoint configuration. If provided, deploys a private endpoint for the storage account.')
param privateEndpointConfig privateEndpointConfigType?

@description('Optional. Public network access setting. Disabled by default for security.')
@allowed([
  'Disabled'
  'Enabled'
  'SecuredByPerimeter'
])
param publicNetworkAccess string = 'Disabled'

@description('Optional. Immutable storage with versioning configuration. If provided, enables account-level immutability.')
param immutableStorageConfig immutableStorageConfigType?

@description('Optional. Enable hierarchical namespace (HNS) for Data Lake Storage Gen2.')
param isHnsEnabled bool = false

@description('Optional. Availability zones for the storage account.')
param zones string[] = []

@description('Required. Resource tags for organization and cost management.')
param tags object

// ============ //
// Variables    //
// ============ //

// Name sanitization - Remove any non-alphanumeric characters from workloadName
// Storage account names must be 3-24 chars, lowercase letters and numbers only
// Use replace() to strip hyphens, toLower() to enforce lowercase
var sanitizedWorkloadName = toLower(replace(workloadName, '-', ''))

// Generate unique suffix using resource group ID to ensure global uniqueness
// uniqueString() creates deterministic 13-char hash from input (same inputs = same output)
// take() extracts first 5 chars for brevity: e.g., 7x9k2
// This ensures storage account names are globally unique across Azure
var uniqueSuffix = take(uniqueString(resourceGroup().id, subscription().id), 5)

// Construct storage account name using sanitized workload name and unique suffix
var StorageAccountName = '${sanitizedWorkloadName}${uniqueSuffix}'
var storageAccountNameLength = length(StorageAccountName)
// Use this at resource deployment - only deploy storage account if this is $true!
var isValidLength = storageAccountNameLength >= 3 && storageAccountNameLength <= 24

// Default Log Analytics workspace for diagnostics if not provided
// This is a centralized LAW for MSFTLabs Environment.. 
var defaultWorkspaceId = '/subscriptions/b18ea7d6-14b5-41f3-a00d-804a5180c589/resourceGroups/msft-core-observability/providers/Microsoft.OperationalInsights/workspaces/msft-core-cus-law'

// Merge provided workspace ID with default using conditional logic
// If diagnosticWorkspaceId is empty string, use default
// empty() function checks for empty string, null, or empty array/object
var mergedWorkspaceId = !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : defaultWorkspaceId


// ============ //
// Resources    //
// ============ //

// Deploy Storage Account using nested module
module storageAccount 'modules/storageAccount.bicep' = if (isValidLength) {
  // uniqueString() in deployment name prevents conflicts when deploying multiple times
  name: '${uniqueString(deployment().name, location)}-storage-account'
  params: {
    storageAccountName: StorageAccountName
    location: location
    kind: kind
    skuName: skuName
    accessTier: accessTier
    defaultToOAuthAuthentication: defaultToOAuthAuthentication
    allowSharedKeyAccess: allowSharedKeyAccess
    allowBlobPublicAccess: allowBlobPublicAccess
    publicNetworkAccess: publicNetworkAccess
    isHnsEnabled: isHnsEnabled
    immutableStorageWithVersioning: immutableStorageConfig
    zones: zones
    tags: tags
  }
}

// Deploy Blob Service if configured
// Conditional deployment using if() - only deploys when blob configuration provided
// Null coalescing operator (??) provides default values when left side is null
// storageAccount.?outputs.name ?? '' safely references output from storage account module, providing empty string if not available
// this is used to create explicit dependency on storage account module ensuring correct deployment order
module blobService 'modules/blobService.bicep' = if (!empty(blobConfig) && isValidLength) {
  name: '${uniqueString(deployment().name, location)}-blob-service'
  params: {
    storageAccountName: storageAccount.?outputs.name ?? ''
    deleteRetentionPolicy: blobConfig.?deleteRetentionPolicy ?? {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: blobConfig.?containerDeleteRetentionPolicy ?? {
      enabled: true
      days: 7
    }
    containers: blobConfig.?containers ?? []
  }
}

// Deploy Queue Service if configured
// Only deployed when queues array is not empty
module queueService 'modules/queueService.bicep' = if (!empty(queueConfig) && isValidLength) {
  name: '${uniqueString(deployment().name, location)}-queue-service'
  params: {
    storageAccountName: storageAccount.?outputs.name ?? ''
    queues: queueConfig.?queues ?? []
  }
}

// Deploy Table Service if configured
// Only deployed when tables array is not empty
// Follows same conditional pattern as other child services
module tableService 'modules/tableService.bicep' = if (!empty(tableConfig) && isValidLength) {
  name: '${uniqueString(deployment().name, location)}-table-service'
  params: {
    storageAccountName: storageAccount.?outputs.name ?? ''
    tables: tableConfig.?tables ?? []
  }
}

// Deploy Diagnostic Settings for metrics collection
module diagnostics 'modules/diagnostics.bicep' = if (enableDiagnostics && isValidLength) {
  name: '${uniqueString(deployment().name, location)}-diagnostics'
  params: {
    storageAccountName: storageAccount.?outputs.name ?? ''
    workspaceId: mergedWorkspaceId
    enableMetrics: true
  }
}

// Deploy Resource Lock to prevent accidental deletion
// CanNotDelete: Allows read/write but prevents delete operations
// ReadOnly: Allows only read operations, blocks write and delete
// Locks are inherited by child resources
module lock 'modules/lock.bicep' = if (enableLock && isValidLength) {
  name: '${uniqueString(deployment().name, location)}-lock'
  params: {
    storageAccountName: storageAccount.?outputs.name ?? ''
    lockLevel: lockLevel
    lockNotes: 'Prevents accidental deletion of ${environment} storage account for ${workloadName}'
  }
}

// Deploy RBAC Role Assignments
// Assigns Azure AD identities to storage account roles (e.g., Blob Data Contributor)
// Uses guid() for deterministic role assignment names ensuring idempotency
module rbac 'modules/rbac.bicep' = if (!empty(roleAssignments) && isValidLength) {
  name: '${uniqueString(deployment().name, location)}-rbac'
  params: {
    storageAccountName: storageAccount.?outputs.name ?? ''
    roleAssignments: roleAssignments
  }
}

// Deploy Private Endpoint for Storage Account
// Conditional deployment - only deploys when privateEndpointConfig is provided
// Requires existing VNet/Subnet and Private DNS Zone infrastructure
module privateEndpoint 'modules/privateEndpoint.bicep' = if (privateEndpointConfig != null && isValidLength) {
  name: '${uniqueString(deployment().name, location)}-private-endpoint'
  params: {
    storageAccountName: storageAccount.?outputs.name ?? ''
    storageAccountResourceId: storageAccount.?outputs.resourceId ?? ''
    subnetResourceId: privateEndpointConfig!.subnetResourceId
    service: privateEndpointConfig!.?service ?? 'blob'
    privateEndpointName: privateEndpointConfig!.?privateEndpointName ?? 'pe-${storageAccount.?outputs.name ?? ''}-${privateEndpointConfig!.?service ?? 'blob'}'
    privateDnsZoneResourceId: privateEndpointConfig!.?privateDnsZoneResourceId ?? ''
    location: location
    tags: tags
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the storage account.')
output resourceId string = storageAccount.?outputs.resourceId ?? ''

@description('The name of the storage account.')
output name string = storageAccount.?outputs.name ?? ''

@description('The resource group the storage account was deployed into.')
output resourceGroupName string = storageAccount.?outputs.resourceGroupName ?? ''

@description('The primary endpoints of the storage account.')
output primaryEndpoints object = storageAccount.?outputs.primaryEndpoints ?? {}

@description('The location the resource was deployed into.')
output location string = storageAccount.?outputs.location ?? ''

@description('The sanitized workload name used in naming.')
output workloadName string = sanitizedWorkloadName

@description('The environment identifier.')
output environment string = environment

@description('The unique naming suffix generated.')
output uniqueSuffix string = uniqueSuffix

// ============== //
// Type Definitions //
// ============== //

@description('Blob service configuration type.')
type blobConfigType = {
  @description('Delete retention policy for blobs.')
  deleteRetentionPolicy: {
    @description('Enable soft delete for blobs.')
    enabled: bool
    @description('Retention days for soft deleted blobs.')
    days: int
  }?

  @description('Container delete retention policy.')
  containerDeleteRetentionPolicy: {
    @description('Enable soft delete for containers.')
    enabled: bool
    @description('Retention days for soft deleted containers.')
    days: int
  }?

  @description('List of blob containers to create.')
  containers: {
    @description('Name of the container.')
    name: string

    @description('Public access level (should always be None for security).')
    publicAccess: ('None' | 'Blob' | 'Container')?

    @description('Optional metadata for the container.')
    metadata: object?
  }[]?
}

@description('Queue service configuration type.')
type queueConfigType = {
  @description('List of queues to create.')
  queues: {
    @description('Name of the queue.')
    name: string

    @description('Optional metadata for the queue.')
    metadata: object?
  }[]?
}

@description('Table service configuration type.')
type tableConfigType = {
  @description('List of tables to create.')
  tables: {
    @description('Name of the table.')
    name: string
  }[]?
}

@description('Role assignment configuration type.')
type roleAssignmentType = {
  @description('The principal ID (object ID) of the identity.')
  principalId: string

  @description('The role definition ID or built-in role name.')
  roleDefinitionIdOrName: string

  @description('The types of principal.')
  principalType: ('ServicePrincipal' | 'Group' | 'User' | 'ManagedIdentity')?
}

@description('Private endpoint configuration type.')
type privateEndpointConfigType = {
  @description('Required. The resource ID of the subnet where the private endpoint will be created.')
  subnetResourceId: string

  @description('Optional. The private link service group ID (sub-resource). Defaults to blob.')
  service: ('blob' | 'file' | 'queue' | 'table' | 'web' | 'dfs')?

  @description('Optional. Custom name for the private endpoint. Auto-generated if not provided.')
  privateEndpointName: string?

  @description('Optional. Resource ID of the Private DNS Zone to link. If empty, DNS zone group is not created.')
  privateDnsZoneResourceId: string?
}

@description('Immutable storage with versioning configuration type.')
type immutableStorageConfigType = {
  @description('Required. Enable account-level immutability. All new containers inherit object-level immutability by default.')
  enabled: bool

  @description('Optional. Account-level immutability policy configuration.')
  immutabilityPolicy: {
    @description('Optional. Allow new blocks to be written to append blobs while maintaining immutability. Default is false.')
    allowProtectedAppendWrites: bool?

    @description('Required. Immutability period in days since policy creation (1-146000).')
    @minValue(1)
    @maxValue(146000)
    immutabilityPeriodSinceCreationInDays: int

    @description('Required. Policy state: Disabled, Unlocked (allows changes), or Locked (only increase retention).')
    state: ('Disabled' | 'Unlocked' | 'Locked')
  }?
}
