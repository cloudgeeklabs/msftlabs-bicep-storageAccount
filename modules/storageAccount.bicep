// ============ //
// Parameters   //
// ============ //

@description('Required. StorageAccount Name.. Must be globally unique, 3-24 characters, lowercase letters and numbers only.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Optional. Azure region for deployment.')
param location string = resourceGroup().location

@description('Optional. Storage Account kind. StorageV2 is most common for general purpose v2 accounts.')
@allowed([
  'Storage'
  'StorageV2'
  'BlobStorage'
  'FileStorage'
  'BlockBlobStorage'
])
param kind string = 'StorageV2'

@description('Optional. Storage Account SKU. Standard_GRS provides geo-redundancy for production workloads.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
param skuName string = 'Standard_GRS'

@description('Optional. Access tier for blob data. Hot tier optimized for frequent access.')
@allowed([
  'Hot'
  'Cool'
  'Premium'
])
param accessTier string = 'Hot'

@description('Optional. Default to OAuth authentication. Recommended to disable key-based auth.')
param defaultToOAuthAuthentication bool = true

@description('Optional. Allow shared key access. Set to false for enhanced security using Azure AD only.')
param allowSharedKeyAccess bool = false

@description('Optional. Allow public blob access. Set to false to prevent anonymous access.')
param allowBlobPublicAccess bool = false

@description('Optional. Public network access setting. Disabled by default for security.')
@allowed([
  'Disabled'
  'Enabled'
  'SecuredByPerimeter'
])
param publicNetworkAccess string = 'Disabled'

@description('Optional. Enable hierarchical namespace (HNS) for Data Lake Storage Gen2. Default is false.')
param isHnsEnabled bool = false

@description('Optional. Immutable storage with versioning configuration. If provided, enables account-level immutability.')
param immutableStorageWithVersioning immutableStorageConfigType?

@description('Optional. Availability zones for the storage account.')
param zones string[] = []

@description('Required. Resource tags for organization and cost tracking.')
param tags object

// ============ //
// Variables    //
// ============ //

// Network ACLs - Default to deny public access, require private endpoints or service endpoints
var networkAcls = {
  defaultAction: 'Deny'
  bypass: 'AzureServices'
} 

@description('Enforce HTTPS traffic only. Should always be true for security.')
var supportsHttpsTrafficOnly = true

@description('Minimum TLS version. TLS 1.2 is required for security compliance.')
param minimumTlsVersion string = 'TLS1_2'

@description('Sanitize storageAccountName. Storage account name must be lowercase and alphanumeric, so this ensures any input is transformed to meet those requirements.')
var sanitizedStorageAccountName = toLower(replace(storageAccountName, '[^a-z0-9]', ''))

// Encryption configuration - Always encrypt with Microsoft-managed keys at minimum!! 
// Customer-managed keys (CMK) can be added for enhanced control and compliance - fix in later version - @BenTheBuilder
var encryption = {
  keySource: 'Microsoft.Storage'
  services: {
    blob: {
      enabled: true
      keyType: 'Account'
    }
    file: {
      enabled: true
      keyType: 'Account'
    }
    queue: {
      enabled: true
      keyType: 'Service'
    }
    table: {
      enabled: true
      keyType: 'Service'
    }
  }
}


// ============ //
// Resources    //
// ============ //

// Deploy Storage Account with security-first configuration
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.storage/storageaccounts
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: sanitizedStorageAccountName
  location: location
  kind: kind
  sku: {
    name: skuName
  }
  tags: tags
  zones: !empty(zones) ? zones : null
  properties: {
    accessTier: accessTier
    minimumTlsVersion: minimumTlsVersion
    supportsHttpsTrafficOnly: supportsHttpsTrafficOnly
    allowSharedKeyAccess: allowSharedKeyAccess
    allowBlobPublicAccess: allowBlobPublicAccess
    defaultToOAuthAuthentication: defaultToOAuthAuthentication
    publicNetworkAccess: publicNetworkAccess
    isHnsEnabled: isHnsEnabled
    immutableStorageWithVersioning: immutableStorageWithVersioning != null ? {
      enabled: immutableStorageWithVersioning!.enabled
      immutabilityPolicy: immutableStorageWithVersioning!.?immutabilityPolicy != null ? {
        allowProtectedAppendWrites: immutableStorageWithVersioning!.immutabilityPolicy!.?allowProtectedAppendWrites ?? false
        immutabilityPeriodSinceCreationInDays: immutableStorageWithVersioning!.immutabilityPolicy!.immutabilityPeriodSinceCreationInDays
        state: immutableStorageWithVersioning!.immutabilityPolicy!.state
      } : null
    } : null
    networkAcls: networkAcls
    encryption: encryption
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the storage account.')
output resourceId string = storageAccount.id

@description('The name of the storage account.')
output name string = storageAccount.name

@description('The resource group the storage account was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The primary endpoints of the storage account.')
output primaryEndpoints object = storageAccount.properties.primaryEndpoints

@description('The location the resource was deployed into.')
output location string = storageAccount.location

@description('The API version used for deployment.')
output apiVersion string = storageAccount.apiVersion

// ============== //
// Type Definitions //
// ============== //

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
