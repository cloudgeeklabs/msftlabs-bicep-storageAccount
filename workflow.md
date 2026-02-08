# Bicep Module Development Workflow

This document outlines the standardized workflow for developing, testing, and publishing Bicep modules to Azure Container Registry (ACR).

## Table of Contents

- [Overview](#overview)
- [Branching Strategy](#branching-strategy)
- [Development Workflow](#development-workflow)
- [Testing Requirements](#testing-requirements)
- [Versioning & Tagging](#versioning--tagging)
- [CI/CD Pipeline](#cicd-pipeline)
- [Best Practices](#best-practices)

---

## Overview

Our Bicep modules follow a gitflow-inspired workflow with automated testing and deployment to ACR. Each module repository contains:

- **Bicep Infrastructure Code** - Main module and sub-modules
- **Pester Tests** - Validation and quality checks
- **GitHub Actions Workflows** - Automated testing and deployment
- **Test Parameters** - Configuration for test runs

### Repository Structure

```
msftlabs-bicep-<moduleName>/
├── .github/
│   └── workflows/
│       ├── unit-tests.yaml      # Runs on PR and push to main
│       └── deploy-module.yaml   # Runs on version tags
├── modules/                      # Sub-modules
├── tests/
│   ├── <moduleName>.tests.ps1   # Pester test suite
│   ├── test.parameters.json     # Test parameters
│   └── ps-rule.yaml             # PSRule configuration
├── main.bicep                    # Module entry point
├── README.md                     # Module documentation
└── CHANGELOG.md                  # Version history
```

---

## Branching Strategy

### Main Branches

- **`main`** - Production-ready code, protected branch
  - Requires PR approval
  - All tests must pass
  - Receives version tags for releases

- **`develop`** - Integration branch for features
  - Optional: Use for pre-release testing
  - Merge to `main` when stable

### Feature Branches

Create feature branches from `main` for all changes:

```bash
# Create feature branch
git checkout main
git pull origin main
git checkout -b feature/add-diagnostic-settings

# Or for bug fixes
git checkout -b fix/resolve-tls-enforcement

# Or for documentation
git checkout -b docs/update-readme
```

### Branch Naming Conventions

- `feature/<description>` - New features or enhancements
- `fix/<description>` - Bug fixes
- `docs/<description>` - Documentation updates
- `test/<description>` - Test improvements
- `refactor/<description>` - Code refactoring

---

## Development Workflow

### 1. Create Feature Branch

```bash
# Ensure main is up to date
git checkout main
git pull origin main

# Create and checkout new branch
git checkout -b feature/add-blob-lifecycle-policy
```

### 2. Make Changes

Edit Bicep files, tests, and documentation:

```bash
# Edit main.bicep or module files
code main.bicep

# Update tests to cover new functionality
code tests/storageAccount.tests.ps1

# Update README with new parameters
code README.md
```

### 3. Test Locally

Run Pester tests before committing:

```bash
# Navigate to tests directory
cd tests

# Run all tests
Invoke-Pester -Path . -Output Detailed

# Or run specific test file
Invoke-Pester -Path storageAccount.tests.ps1 -Output Detailed
```

Compile Bicep to verify syntax:

```bash
# Build ARM template from Bicep
bicep build main.bicep

# Check for warnings or errors
```

### 4. Commit Changes

Follow conventional commit messages:

```bash
# Stage changes
git add main.bicep tests/storageAccount.tests.ps1

# Commit with descriptive message
git commit -m "feat: Add blob lifecycle management policy

- Added lifecyclePolicy parameter
- Created lifecycle management module
- Added Pester tests for lifecycle rules
- Updated README with new parameter documentation"
```

### Commit Message Conventions

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `test:` - Test additions or changes
- `refactor:` - Code refactoring
- `chore:` - Maintenance tasks
- `ci:` - CI/CD changes

### 5. Push Feature Branch

```bash
# Push to origin
git push origin feature/add-blob-lifecycle-policy
```

### 6. Create Pull Request

1. Navigate to GitHub repository
2. Click "Compare & pull request"
3. Fill in PR template:
   - **Title**: Brief description
   - **Description**: Detailed changes, breaking changes, migration notes
   - **Checklist**: Tests pass, documentation updated
4. Request review from team members
5. Address review comments if needed

### 7. Merge to Main

Once approved and tests pass:

```bash
# Option 1: Merge via GitHub UI (recommended)
# - Use "Squash and merge" for clean history
# - Use "Merge commit" to preserve all commits

# Option 2: Merge locally
git checkout main
git merge feature/add-blob-lifecycle-policy
git push origin main

# Delete feature branch
git branch -d feature/add-blob-lifecycle-policy
git push origin --delete feature/add-blob-lifecycle-policy
```

---

## Testing Requirements

All changes must pass automated tests before merging.

### Pester Tests

Located in `tests/<moduleName>.tests.ps1`, tests validate:

1. **Static Analysis**
   - Bicep syntax validation
   - ARM template generation
   - Security defaults
   - Naming conventions
   - TLS enforcement

2. **Template Validation**
   - ARM schema compliance
   - Module deployment structure
   - Required parameters
   - Output definitions

### Running Tests Locally

```bash
# Navigate to tests directory
cd tests

# Run all tests with detailed output
Invoke-Pester -Path . -Output Detailed

# Run tests and generate XML report
$config = New-PesterConfiguration
$config.Run.Path = '.'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = './test-results.xml'
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
```

### Test Requirements

- **All tests must pass** before creating PR
- **No breaking changes** without documentation
- **Code coverage** for new features
- **Valid Bicep syntax** (no warnings)

---

## Versioning & Tagging

We follow **Semantic Versioning (SemVer)**: `MAJOR.MINOR.PATCH`

### Version Format

- **MAJOR** (v2.0.0) - Breaking changes, incompatible API changes
- **MINOR** (v1.1.0) - New features, backward-compatible
- **PATCH** (v1.0.1) - Bug fixes, backward-compatible

### When to Increment

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Breaking parameter name change | MAJOR | v1.5.2 → v2.0.0 |
| New optional parameter | MINOR | v1.5.2 → v1.6.0 |
| Bug fix, no API changes | PATCH | v1.5.2 → v1.5.3 |
| Documentation only | PATCH | v1.5.2 → v1.5.3 |

### Creating Version Tags

**After merging to main:**

```bash
# Ensure main is up to date
git checkout main
git pull origin main

# Create annotated tag
git tag -a v1.2.0 -m "Release version 1.2.0

- Added blob lifecycle management
- Improved diagnostic settings
- Fixed TLS enforcement bug"

# Push tag to trigger deployment
git push origin v1.2.0
```

### Tag Naming Conventions

- Use `v` prefix: `v1.0.0`, `v2.1.3`
- Include descriptive message with `-m`
- List major changes in tag annotation
- Reference issues/PRs if applicable

### Pre-release Tags

For beta or release candidate versions:

```bash
# Beta release
git tag -a v1.2.0-beta.1 -m "Beta release for testing"

# Release candidate
git tag -a v1.2.0-rc.1 -m "Release candidate 1"

# Push pre-release tag
git push origin v1.2.0-beta.1
```

---

## CI/CD Pipeline

### Unit Tests Workflow

**Trigger:** Push to `main`, `develop`, or Pull Requests

**File:** `.github/workflows/unit-tests.yaml`

**Steps:**
1. Checkout code
2. Install Pester 5.x
3. Update test parameters (unique names)
4. Run Pester tests with detailed output
5. Generate test summary in GitHub Actions UI

**What it validates:**
- Bicep syntax
- ARM template generation
- Security configurations
- Naming conventions
- Module structure

### Deploy Module Workflow

**Trigger:** Version tags (e.g., `v1.0.0`, `v1.2.3`)

**File:** `.github/workflows/deploy-module.yaml`

**Steps:**
1. Authenticate via Service Principal
   - Retrieves credentials from GitHub Secrets
   - Azure CLI login with SPN
2. Build Bicep module
   - Compiles to ARM template
   - Validates syntax
3. Publish to ACR
   - Pushes to `msftlabsbicepmods.azurecr.io`
   - Tags with version number
   - Creates `latest` alias

**Published module format:**
```
br:msftlabsbicepmods.azurecr.io/bicep/<moduleName>:v1.0.0
br:msftlabsbicepmods.azurecr.io/bicep/<moduleName>:latest
```

### GitHub Secrets Required

Configured via `setup-secrets.ps1`:

- `AZURE_CLIENT_ID` - Service Principal Application ID
- `AZURE_CLIENT_SECRET` - Service Principal Secret
- `AZURE_TENANT_ID` - Azure AD Tenant ID
- `AZURE_SUBSCRIPTION_ID` - Azure Subscription ID

---

## Best Practices

### Code Quality

✅ **DO:**
- Use descriptive parameter names
- Add parameter descriptions with `@description()`
- Set appropriate default values
- Use parameter constraints (`@minLength`, `@maxLength`, `@allowed`)
- Include security defaults (TLS 1.2+, disable public access)
- Add resource tags for organization
- Use modules for reusability
- Comment complex logic

❌ **DON'T:**
- Hardcode values (use parameters)
- Skip parameter validation
- Expose secrets in plain text
- Use outdated API versions
- Ignore Bicep warnings

### Testing

✅ **DO:**
- Test locally before pushing
- Cover new features with tests
- Validate both success and failure scenarios
- Use validation-only tests (no actual deployments)
- Update test parameters as needed

❌ **DON'T:**
- Skip tests to save time
- Commit failing tests
- Remove tests to pass CI
- Use production credentials in tests

### Git Workflow

✅ **DO:**
- Pull main before creating feature branches
- Write clear commit messages
- Keep commits focused and atomic
- Review your own PR before requesting review
- Delete branches after merging
- Tag releases consistently

❌ **DON'T:**
- Commit directly to main
- Force push to main or develop
- Commit sensitive data (credentials, keys)
- Create massive multi-purpose commits
- Forget to update CHANGELOG.md

### Documentation

✅ **DO:**
- Update README.md with parameter changes
- Document breaking changes clearly
- Add examples for complex usage
- Update CHANGELOG.md for each release
- Include migration guides for major versions

❌ **DON'T:**
- Skip documentation updates
- Assume parameters are self-explanatory
- Leave outdated examples in README

### Versioning

✅ **DO:**
- Follow SemVer strictly
- Tag after merging to main
- Include release notes in tags
- Test before tagging releases
- Communicate breaking changes

❌ **DON'T:**
- Reuse version tags
- Tag untested code
- Make breaking changes in minor versions
- Skip versions arbitrarily

---

## Example: Complete Feature Development Flow

### Scenario: Add Network Rules to Storage Account Module

#### Step 1: Create Feature Branch

```bash
git checkout main
git pull origin main
git checkout -b feature/add-network-rules
```

#### Step 2: Implement Changes

**Update `main.bicep`:**

```bicep
@description('Optional. Network rules for storage account access.')
param networkRules object = {
  defaultAction: 'Deny'
  bypass: 'AzureServices'
  ipRules: []
  virtualNetworkRules: []
}
```

**Create `modules/networkRules.bicep`:**

```bicep
// Module for network rule configuration
param storageAccountName string
param networkRules object

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// Apply network rules
resource networkRule 'Microsoft.Storage/storageAccounts/networkRuleSets@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    defaultAction: networkRules.defaultAction
    bypass: networkRules.bypass
    ipRules: [for rule in networkRules.ipRules: {
      value: rule.value
      action: 'Allow'
    }]
    virtualNetworkRules: [for rule in networkRules.virtualNetworkRules: {
      id: rule.id
      action: 'Allow'
    }]
  }
}
```

**Update tests:**

```powershell
It "Should enforce network rules" {
    $content = Get-Content $TemplatePath -Raw
    $content | Should -Match 'networkRules'
}
```

#### Step 3: Test Locally

```bash
# Compile Bicep
bicep build main.bicep

# Run Pester tests
cd tests
Invoke-Pester -Path . -Output Detailed
```

#### Step 4: Commit and Push

```bash
git add main.bicep modules/networkRules.bicep tests/storageAccount.tests.ps1 README.md
git commit -m "feat: Add network rules configuration

- Added networkRules parameter with default deny policy
- Created networkRules module for firewall configuration
- Added IP rules and VNet rules support
- Updated tests to validate network security
- Updated README with network rules examples"

git push origin feature/add-network-rules
```

#### Step 5: Create Pull Request

- Open PR on GitHub
- Add description and breaking change notes
- Request review from team
- Wait for CI tests to pass

#### Step 6: Merge to Main

```bash
# After approval, merge via GitHub UI
# Or merge locally:
git checkout main
git merge feature/add-network-rules
git push origin main

# Delete feature branch
git branch -d feature/add-network-rules
git push origin --delete feature/add-network-rules
```

#### Step 7: Create Release Tag

```bash
# Update CHANGELOG.md with v1.3.0 changes
git add CHANGELOG.md
git commit -m "docs: Update changelog for v1.3.0"
git push origin main

# Create and push tag
git tag -a v1.3.0 -m "Release version 1.3.0

Features:
- Network rules configuration
- IP-based access control
- VNet service endpoints support

Breaking Changes: None"

git push origin v1.3.0
```

#### Step 8: Verify Deployment

Monitor GitHub Actions:
- Unit tests pass ✅
- Module published to ACR ✅
- Available at: `br:msftlabsbicepmods.azurecr.io/bicep/storageaccount:v1.3.0`

---

## Troubleshooting

### Tests Failing Locally

```bash
# Check Bicep syntax
bicep build main.bicep

# Run specific test with verbose output
Invoke-Pester -Path tests/storageAccount.tests.ps1 -Output Detailed
```

### Deployment Workflow Failing

1. Check GitHub Secrets are configured:
   ```bash
   gh secret list --repo cloudgeeklabs/msftlabs-bicep-<module>
   ```

2. Verify Service Principal has ACR permissions:
   ```bash
   az role assignment list --assignee <CLIENT_ID> --scope <ACR_RESOURCE_ID>
   ```

3. Check workflow logs in GitHub Actions

### Tag Already Exists

```bash
# Delete local tag
git tag -d v1.0.0

# Delete remote tag
git push origin --delete v1.0.0

# Recreate tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

---

## Additional Resources

- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/)
- [Pester Testing Framework](https://pester.dev/)
- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)

---

**Last Updated:** February 7, 2026  
**Repository:** msftlabs-bicep-modules  
**Maintainer:** cloudgeeklabs
