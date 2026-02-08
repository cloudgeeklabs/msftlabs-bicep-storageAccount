# Storage Account Bicep Module

A production-ready Azure Bicep module for deploying Storage Accounts with enterprise security defaults, comprehensive testing, and CI/CD automation.

## Table of Contents

- [Features](#features)
- [Module Information](#module-information)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Usage Examples](#usage-examples)
- [Parameters](#parameters)
- [Outputs](#outputs)
- [Testing](#testing)
- [CI/CD Workflows](#cicd-workflows)
- [Publishing to ACR](#publishing-to-acr)
- [Development](#development)
- [Troubleshooting](#troubleshooting)

## Features

- **Secure by Default**: OAuth authentication, disabled shared key access, no public blob access
- **TLS 1.2 Enforcement**: Minimum TLS version enforced**Multi-Service Support**: Blob containers, queues, and tables
- **Private Endpoints**: Optional private endpoint configuration
- **Diagnostics Integration**: Automatic Log Analytics workspace integration
- **Resource Locking**: CanNotDelete lock to prevent accidental deletion
- **RBAC Support**: Built-in role assignment configuration
- **Comprehensive Testing**: Native Bicep, Pester, and PSRule validation
- **CI/CD Ready**: Automated testing and ACR deployment workflows

## Module Information

- **Module Name**: `storageAccounts`
- **Description**: This module deploys a Storage Account with all required settings/configurations
- **ACR Registry**: `msftlabsbicepmods.azurecr.io`
- **Module Path**: `bicep/modules/storageaccount`
- **Current Version**: 1.0.0

## Prerequisites

- Azure CLI 2.50.0 or later
- Bicep CLI 0.20.0 or later
- PowerShell 7.0 or later (for Pester tests)
- Pester 5.0.0 or later (for unit testing)
- Azure subscription with permissions to:
  - Create storage accounts
  - Assign RBAC roles
  - Create resource locks
  - Configure diagnostics settings
- Access to ACR: `msftlabsbicepmods.azurecr.io`

## Quick Start

### Using the Module from ACR

```bicep
module storage 'br:msftlabsbicepmods.azurecr.io/bicep/modules/storageaccount:1.0.0' = {
  name: 'storageDeployment'
  params: {
    storageAccountName: 'mystore${uniqueString(resourceGroup().id)}'
    location: 'centralus'
    tags: {
      Environment: 'Production'
      ManagedBy: 'Bicep'
    }
  }
}
```

### Using Module Alias

Configure `bicepconfig.json`:

```json
{
  "moduleAliases": {
    "br": {
      "msftlabsbicepmods": {
        "registry": "msftlabsbicepmods.azurecr.io",
        "modulePath": "bicep/modules"
      }
    }
  }
}
```

Then reference:

```bicep
module storage 'br/msftlabsbicepmods:storageaccount:1.0.0' = {
  name: 'storageDeployment'
  params: {
    storageAccountName: 'mystore${uniqueString(resourceGroup().id)}'
    tags: {
      Environment: 'Production'
    }
  }
}
```

### Deploy

```bash
az deployment group create \
  --resource-group rg-production \
  --template-file main.bicep \
  --name storage-deployment
```

## Usage Examples

### Minimal Configuration

```bicep
module storage 'br/msftlabsbicepmods:storageaccount:1.0.0' = {
  name: 'minimalStorage'
  params: {
    storageAccountName: 'minimal${uniqueString(resourceGroup().id)}'
    tags: { Environment: 'Dev' }
  }
}
```

### With Containers and Queues

```bicep
module storage 'br/msftlabsbicepmods:storageaccount:1.0.0' = {
  name: 'storageWithServices'
  params: {
    storageAccountName: 'appdata${uniqueString(resourceGroup().id)}'
    containerServices: {
      deleteRetentionPolicy: {
        enabled: true
        days: 30
      }
      containers: [
        { name: 'uploads', publicAccess: 'None' }
        { name: 'processed', publicAccess: 'None' }
      ]
    }
    queueServices: {
      queues: [
        { name: 'processing-queue' }
      ]
    }
    tags: {
      Environment: 'Production'
      Application: 'DataPipeline'
    }
  }
}
```

### With Private Endpoints

```bicep
module storage 'br/msftlabsbicepmods:storageaccount:1.0.0' = {
  name: 'secureStorage'
  params: {
    storageAccountName: 'secure${uniqueString(resourceGroup().id)}'
    privateEndpoints: [
      {
        name: 'pe-storage-blob'
        service: 'blob'
        subnetResourceId: '/subscriptions/.../subnets/private-endpoints'
      }
    ]
    tags: { Security: 'High' }
  }
}
```

### With RBAC Assignments

```bicep
module storage 'br/msftlabsbicepmods:storageaccount:1.0.0' = {
  name: 'storageWithRBAC'
  params: {
    storageAccountName: 'rbac${uniqueString(resourceGroup().id)}'
    roleAssignments: [
      {
        principalId: '<managed-identity-principal-id>'
        roleDefinitionIdOrName: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
        principalType: 'ServicePrincipal'
      }
    ]
    tags: { Environment: 'Production' }
  }
}
```

## Parameters

| Parameter                        | Type   | Default                      | Required | Description                        |
| -------------------------------- | ------ | ---------------------------- | -------- | ---------------------------------- |
| `storageAccountName`           | string | -                            | Yes      | Name (3-24 chars, globally unique) |
| `location`                     | string | `resourceGroup().location` | No       | Azure region                       |
| `kind`                         | string | `StorageV2`                | No       | Storage Account kind               |
| `skuName`                      | string | `Standard_GRS`             | No       | SKU name                           |
| `accessTier`                   | string | `Hot`                      | No       | Access tier                        |
| `defaultToOAuthAuthentication` | bool   | `true`                     | No       | OAuth authentication               |
| `allowSharedKeyAccess`         | bool   | `false`                    | No       | Shared key access                  |
| `allowBlobPublicAccess`        | bool   | `false`                    | No       | Public blob access                 |
| `privateEndpoints`             | array  | `[]`                       | No       | Private endpoint configs           |
| `containerServices`            | object | `{}`                       | No       | Container configurations           |
| `queueServices`                | object | `{}`                       | No       | Queue configurations               |
| `tableServices`                | object | `{}`                       | No       | Table configurations               |
| `diagnosticWorkspaceId`        | string | Default LAW                  | No       | Log Analytics workspace ID         |
| `roleAssignments`              | array  | `[]`                       | No       | RBAC assignments                   |
| `tags`                         | object | -                            | Yes      | Resource tags                      |

## Outputs

| Output                | Type   | Description                 |
| --------------------- | ------ | --------------------------- |
| `resourceId`        | string | Storage Account resource ID |
| `name`              | string | Storage Account name        |
| `resourceGroupName` | string | Resource group name         |
| `primaryEndpoints`  | object | Primary endpoints           |
| `location`          | string | Deployment location         |

## Testing

The module includes comprehensive testing at multiple levels:

### Test Structure

```
tests/
├── storageAccount.tests.ps1    # Pester unit tests
├── test.parameters.json         # Test parameters
└── ps-rule.yaml                # PSRule configuration
```

### Running Tests Locally

#### Native Bicep Validation

```bash
# Build and validate syntax
az bicep build --file main.bicep

# What-if analysis
az deployment group what-if \
  --resource-group rg-test \
  --template-file main.bicep \
  --parameters tests/test.parameters.json
```

#### Pester Unit Tests

```powershell
# Install Pester 5.x
Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0.0

# Run all tests
Invoke-Pester -Path ./tests -Output Detailed

# Run with code coverage
$config = New-PesterConfiguration
$config.Run.Path = './tests'
$config.CodeCoverage.Enabled = $true
Invoke-Pester -Configuration $config
```

#### PSRule Analysis

```powershell
# Install PSRule
Install-Module -Name PSRule.Rules.Azure -Force

# Run PSRule analysis
Invoke-PSRule -InputPath . -Module PSRule.Rules.Azure -Format File
```

### Test Coverage

The Pester tests validate:

- **Static Analysis**: Bicep syntax, required metadata, parameters
- **What-If Analysis**: Resource creation, diagnostic settings, locks
- **Deployment Validation**: Successful deployment, outputs, SKU configuration
- **Security Validation**: TLS version, key access, public blob access
- **Governance Validation**: Resource locks, tags

## CI/CD Workflows

The module includes three GitHub Actions workflows:

### 1. Static Analysis (`static-test.yaml`)

Runs on every push and PR:

- Bicep build and lint
- ARM template validation
- What-if analysis
- PSRule analysis with SARIF output

### 2. Unit Tests (`unit-tests.yaml`)

Runs Pester tests on every push and PR:

- Full Pester test suite
- NUnit XML test results
- Test result publishing
- Detailed test summary

### 3. Deploy Module (`deploy-module.yaml`)

Triggered by version tags or manual dispatch:

- Validates version format
- Checks for version duplicates
- Publishes to ACR with version and latest tags
- Creates GitHub release
- Generates deployment summary

## Publishing to ACR

### Automated Publishing

Create and push a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The `deploy-module.yaml` workflow automatically publishes to ACR.

### Manual Publishing

```bash
# Login to Azure and ACR
az login
az acr login --name msftlabsbicepmods

# Publish specific version
az bicep publish \
  --file main.bicep \
  --target br:msftlabsbicepmods.azurecr.io/bicep/modules/storageaccount:1.0.0

# Publish latest tag
az bicep publish \
  --file main.bicep \
  --target br:msftlabsbicepmods.azurecr.io/bicep/modules/storageaccount:latest \
  --force
```

### Verify Publication

```bash
az acr repository show-tags \
  --name msftlabsbicepmods \
  --repository bicep/modules/storageaccount \
  --output table
```

## Development

### Module Structure

```
msftlabs-bicep-storageAccount/
├── .github/
│   └── workflows/
│       ├── static-test.yaml     # Static analysis and validation
│       ├── unit-tests.yaml      # Pester unit tests
│       └── deploy-module.yaml   # ACR deployment
├── tests/
│   ├── storageAccount.tests.ps1 # Pester tests
│   ├── test.parameters.json     # Test parameters
│   └── ps-rule.yaml             # PSRule configuration
├── .gitignore                   # Git ignore rules
├── bicepconfig.json             # Bicep configuration
├── CHANGELOG.md                 # Version history
├── main.bicep                   # Main module
└── README.md                    # This file
```

### Development Workflow

1. **Make Changes**: Edit `main.bicep`
2. **Test Locally**: Run Pester tests
3. **Commit**: Commit changes with descriptive message
4. **Push**: Push to feature branch
5. **PR**: Create pull request (triggers static and unit tests)
6. **Merge**: Merge to main
7. **Tag**: Create version tag
8. **Deploy**: Automatic deployment to ACR

### Version Management

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (x.0.0): Breaking changes
- **MINOR** (1.x.0): New features, backward compatible
- **PATCH** (1.0.x): Bug fixes

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests locally
5. Submit a pull request

### Best Practices

- Always run tests before committing
- Update CHANGELOG.md for each version
- Use descriptive commit messages
- Follow existing code style
- Add tests for new features
- Update documentation

## Troubleshooting

### ACR Login Issues

```bash
# Verify ACR access
az acr repository list --name msftlabsbicepmods

# Grant AcrPull role if needed
az role assignment create \
  --assignee <user-or-sp-id> \
  --role AcrPull \
  --scope /subscriptions/b18ea7d6-14b5-41f3-a00d-804a5180c589/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/msftlabsbicepmods
```

### Test Failures

```powershell
# Run tests with verbose output
Invoke-Pester -Path ./tests -Output Detailed

# Run specific test
Invoke-Pester -Path ./tests -Tag 'StaticAnalysis'
```

### Build Errors

```bash
# Check Bicep version
az bicep version

# Upgrade Bicep
az bicep upgrade

# Validate syntax
az bicep build --file main.bicep
```

## Resources

- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Bicep Modules](https://learn.microsoft.com/azure/azure-resource-manager/bicep/modules)
- [Pester Documentation](https://pester.dev/)
- [PSRule for Azure](https://azure.github.io/PSRule.Rules.Azure/)
- [GitHub Actions](https://docs.github.com/actions)

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:

- Open a GitHub Issue
- Contact: bemitchell@cloudgeeklabs.com

---

**Module Version**: 1.0.0
**Last Updated**: February 2026
**Maintained By**: Microsoft Labs Training Team

### Minimal Configuration

```bicep
module storage 'br/msftlabsbicepmods:storageaccount:latest' = {
  name: 'minimalStorage'
  params: {
    storageAccountName: 'mystorageacct${uniqueString(resourceGroup().id)}'
    tags: {
      Environment: 'Dev'
    }
  }
}
```

### With Containers and Queues

```bicep
module storage 'br/msftlabsbicepmods:storageaccount:1.0.0' = {
  name: 'storageWithServices'
  params: {
    storageAccountName: 'appdata${uniqueString(resourceGroup().id)}'
    containerServices: {
      containers: [
        {
          name: 'uploads'
          publicAccess: 'None'
        }
        {
          name: 'processed'
          publicAccess: 'None'
          metadata: {
            retention: '90days'
          }
        }
      ]
    }
    queueServices: {
      queues: [
        {
          name: 'processing-queue'
        }
      ]
    }
    tags: {
      Environment: 'Production'
      Application: 'DataPipeline'
    }
  }
}
```

### With Private Endpoints

```bicep
module storage 'br/msftlabsbicepmods:storageaccount:1.0.0' = {
  name: 'privateStorage'
  params: {
    storageAccountName: 'securestorage${uniqueString(resourceGroup().id)}'
    privateEndpoints: [
      {
        name: 'pe-storage-blob'
        service: 'blob'
        subnetResourceId: '/subscriptions/.../subnets/private-endpoints'
      }
    ]
    tags: {
      Environment: 'Production'
      Security: 'High'
    }
  }
}
```

### With RBAC Assignments

```bicep
module storage 'br/msftlabsbicepmods:storageaccount:1.0.0' = {
  name: 'storageWithRBAC'
  params: {
    storageAccountName: 'appstorage${uniqueString(resourceGroup().id)}'
    roleAssignments: [
      {
        principalId: '00000000-0000-0000-0000-000000000000'
        roleDefinitionIdOrName: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
        principalType: 'ServicePrincipal'
      }
    ]
    tags: {
      Environment: 'Production'
    }
  }
}
```

## Publishing to ACR

### Automated Publishing (GitHub Actions)

The module is automatically published when you create a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

### Manual Publishing

```bash
# Login to Azure
az login

# Login to ACR
az acr login --name msftlabsbicepmods

# Publish module
az bicep publish \
  --file main.bicep \
  --target br:msftlabsbicepmods.azurecr.io/bicep/modules/storageaccount:1.0.0
```

### List Published Versions

```bash
az acr repository show-tags \
  --name msftlabsbicepmods \
  --repository bicep/modules/storageaccount
```

## Development

### Module Structure

```
msftlabs-bicep-storageAccount/
├── .github/
│   └── workflows/
│       ├── static-test.yaml     # Static analysis and validation
│       ├── unit-tests.yaml      # Pester unit tests
│       └── deploy-module.yaml   # ACR deployment
├── tests/
│   ├── storageAccount.tests.ps1 # Pester tests
│   ├── test.parameters.json     # Test parameters
│   └── ps-rule.yaml             # PSRule configuration
├── .gitignore                   # Git ignore rules
├── bicepconfig.json             # Bicep configuration
├── CHANGELOG.md                 # Version history
├── main.bicep                   # Main module
└── README.md                    # This file
```

### Development Workflow

1. **Make Changes**: Edit `main.bicep`
2. **Test Locally**: Run Pester tests
3. **Commit**: Commit changes with descriptive message
4. **Push**: Push to feature branch
5. **PR**: Create pull request (triggers static and unit tests)
6. **Merge**: Merge to main
7. **Tag**: Create version tag
8. **Deploy**: Automatic deployment to ACR

### Version Management

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (x.0.0): Breaking changes
- **MINOR** (1.x.0): New features, backward compatible
- **PATCH** (1.0.x): Bug fixes

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests locally
5. Submit a pull request

### Best Practices

- Always run tests before committing
- Update CHANGELOG.md for each version
- Use descriptive commit messages
- Follow existing code style
- Add tests for new features
- Update documentation

## Troubleshooting

### ACR Login Issues

```bash
# Verify ACR access
az acr repository list --name msftlabsbicepmods

# Grant AcrPull role if needed
az role assignment create \
  --assignee <user-or-sp-id> \
  --role AcrPull \
  --scope /subscriptions/b18ea7d6-14b5-41f3-a00d-804a5180c589/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/msftlabsbicepmods
```

### Test Failures

```powershell
# Run tests with verbose output
Invoke-Pester -Path ./tests -Output Detailed

# Run specific test
Invoke-Pester -Path ./tests -Tag 'StaticAnalysis'
```

### Build Errors

```bash
# Check Bicep version
az bicep version

# Upgrade Bicep
az bicep upgrade

# Validate syntax
az bicep build --file main.bicep
```

## Resources

- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Bicep Modules](https://learn.microsoft.com/azure/azure-resource-manager/bicep/modules)
- [Pester Documentation](https://pester.dev/)
- [PSRule for Azure](https://azure.github.io/PSRule.Rules.Azure/)
- [GitHub Actions](https://docs.github.com/actions)

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:

- Open a GitHub Issue
- Contact: bemitchell@cloudgeeklabs.com

---

**Module Version**: 1.0.0
**Last Updated**: February 2026
**Maintained By**: Microsoft Labs Training Team
