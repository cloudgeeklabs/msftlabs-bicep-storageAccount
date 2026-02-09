#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    $ModulePath = Split-Path -Parent $PSScriptRoot
    $TemplatePath = Join-Path $ModulePath 'modules' 'storageAccount.bicep'
    $ParametersPath = Join-Path $PSScriptRoot 'test.parameters.json'
    $script:ValidateOutputPath = Join-Path $PSScriptRoot 'validate.json'
    $script:AzureAvailable = $false

    # Build the Bicep template (only needs az bicep CLI, not auth)
    Write-Host 'Building Bicep template...' -ForegroundColor Cyan
    $armOutputPath = Join-Path $ModulePath 'modules' 'storageAccount.bicep.json'
    az bicep build --file $TemplatePath --outfile $armOutputPath 2>&1 | Out-Null

    # Check Azure authentication before attempting resource group operations
    $null = az account show --output none 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Azure CLI not authenticated - skipping validation tests (static analysis tests will still run)'
    } else {
        $script:AzureAvailable = $true

        # Create a randomly named resource group for validation
        $randomSuffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
        $script:TestResourceGroup = "rg-pester-validate-$randomSuffix"
        $script:TestLocation = 'centralus'

        Write-Host ('Creating temporary resource group: {0}' -f $script:TestResourceGroup) -ForegroundColor Cyan
        az group create --name $script:TestResourceGroup --location $script:TestLocation --output none 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning ('Failed to create resource group: {0} - validation tests will be skipped' -f $script:TestResourceGroup)
            $script:AzureAvailable = $false
        } else {
            # Run bicep validation and capture output as JSON
            Write-Host 'Running bicep validation with test parameters...' -ForegroundColor Cyan
            $validateResult = az deployment group validate `
                --resource-group $script:TestResourceGroup `
                --template-file $TemplatePath `
                --parameters $ParametersPath `
                --no-prompt `
                --output json 2>$null

            $script:ValidateExitCode = $LASTEXITCODE

            # Save validation output to JSON file
            if ($script:ValidateExitCode -eq 0 -and $validateResult) {
                $validateResult | Out-File -FilePath $script:ValidateOutputPath -Encoding utf8
                Write-Host ('Validation output saved to: {0}' -f $script:ValidateOutputPath) -ForegroundColor Green
            } else {
                # On failure, re-run capturing stderr for diagnostics
                $errorOutput = az deployment group validate `
                    --resource-group $script:TestResourceGroup `
                    --template-file $TemplatePath `
                    --parameters $ParametersPath `
                    --no-prompt `
                    --output json 2>&1
                $errorText = ($errorOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) -join "`n"
                $jsonMatch = [regex]::Match($errorText, '\{.*\}')
                if ($jsonMatch.Success) {
                    $jsonMatch.Value | Out-File -FilePath $script:ValidateOutputPath -Encoding utf8
                } else {
                    $errorText | Out-File -FilePath $script:ValidateOutputPath -Encoding utf8
                }
                Write-Warning ('Validation failed with exit code: {0}' -f $script:ValidateExitCode)
            }
        }
    }

    # Parse validation output for use in tests
    $script:ValidationOutput = if (Test-Path $script:ValidateOutputPath) {
        Get-Content $script:ValidateOutputPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    } else {
        $null
    }
}

Describe "Bicep Module: Storage Account" {
    
    Context "Static Analysis" {
        
        It "Should have valid Bicep syntax" {
            $null = az bicep build --file $TemplatePath 2>&1
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should generate ARM template" {
            $armTemplatePath = Join-Path $ModulePath 'modules' 'storageAccount.bicep.json'
            Test-Path $armTemplatePath | Should -Be $true
        }
        
        It "Should have security defaults" {
            $content = Get-Content $TemplatePath -Raw
            $content | Should -Match "allowSharedKeyAccess.*false"
            $content | Should -Match "allowBlobPublicAccess.*false"
            $content | Should -Match "defaultToOAuthAuthentication.*true"
        }
        
        It "Should have storage account name sanitization" {
            $moduleContent = Get-Content $TemplatePath -Raw
            $moduleContent | Should -Match "var sanitizedStorageAccountName"
            $moduleContent | Should -Match "toLower"
            $moduleContent | Should -Match "replace.*storageAccountName"
        }
        
        It "Should enforce TLS 1.2 minimum" {
            $moduleContent = Get-Content $TemplatePath -Raw
            $moduleContent | Should -Match "minimumTlsVersion.*TLS1_2"
        }
        
        It "Should sanitize storage account name to Azure standards" {
            $moduleContent = Get-Content $TemplatePath -Raw
            $moduleContent | Should -Match "replace.*\[.*a-z0-9.*\]"
        }
        
        It "Should enforce storage account name length constraints" {
            $moduleContent = Get-Content $TemplatePath -Raw
            $moduleContent | Should -Match "@minLength\(3\)"
            $moduleContent | Should -Match "@maxLength\(24\)"
        }
    }
    
    Context "Validation Output Tests" {

        BeforeAll {
            $armPath = Join-Path $ModulePath 'modules' 'storageAccount.bicep.json'
            $script:ArmTemplate = if (Test-Path $armPath) {
                Get-Content $armPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            } else { $null }

            if ($script:AzureAvailable -and $script:ValidationOutput) {
                $script:Params = $script:ValidationOutput.properties.parameters
                $script:ValidatedResource = $script:ValidationOutput.properties.validatedResources |
                    Where-Object { $_.id -match 'Microsoft.Storage/storageAccounts' }
            }
        }
        
        It "Should have validation output file" -Skip:(-not $script:AzureAvailable) {
            Test-Path $script:ValidateOutputPath | Should -Be $true
        }
        
        It "Should have valid validation output JSON" -Skip:(-not $script:AzureAvailable) {
            $script:ValidationOutput | Should -Not -BeNullOrEmpty
        }
        
        It "Should pass validation without errors" -Skip:(-not $script:AzureAvailable) {
            $script:ValidationOutput.error | Should -BeNullOrEmpty
            $script:ValidationOutput.properties.provisioningState | Should -Be 'Succeeded'
        }
        
        It "Should have validated resources in output" -Skip:(-not $script:AzureAvailable) {
            $script:ValidatedResource | Should -Not -BeNullOrEmpty
        }

        It "Should validate storage account name is sanitized" -Skip:(-not $script:AzureAvailable) {
            $name = ($script:ValidatedResource.id -split '/')[-1]
            $name | Should -Match '^[a-z0-9]{3,24}$'
        }

        It "Should validate SKU is Standard_LRS from parameters" -Skip:(-not $script:AzureAvailable) {
            $script:Params.skuName.value | Should -Be 'Standard_LRS'
        }
        
        It "Should validate kind is StorageV2 from parameters" -Skip:(-not $script:AzureAvailable) {
            $script:Params.kind.value | Should -Be 'StorageV2'
        }

        It "Should validate access tier is Hot from parameters" -Skip:(-not $script:AzureAvailable) {
            $script:Params.accessTier.value | Should -Be 'Hot'
        }

        It "Should validate shared key access is disabled" -Skip:(-not $script:AzureAvailable) {
            $script:Params.allowSharedKeyAccess.value | Should -Be $false
        }
        
        It "Should validate blob public access is disabled" -Skip:(-not $script:AzureAvailable) {
            $script:Params.allowBlobPublicAccess.value | Should -Be $false
        }
        
        It "Should validate OAuth authentication is default" -Skip:(-not $script:AzureAvailable) {
            $script:Params.defaultToOAuthAuthentication.value | Should -Be $true
        }

        It "Should validate minimum TLS version is 1.2" -Skip:(-not $script:AzureAvailable) {
            $script:Params.minimumTlsVersion.value | Should -Be 'TLS1_2'
        }

        It "Should validate tags are applied from parameters" -Skip:(-not $script:AzureAvailable) {
            $script:Params.tags.value | Should -Not -BeNullOrEmpty
            $script:Params.tags.value.ManagedBy | Should -Be 'Pester'
            $script:Params.tags.value.Environment | Should -Be 'Test'
            $script:Params.tags.value.Purpose | Should -Be 'ModuleTesting'
        }

        It "Should have HTTPS-only enforced in ARM template" {
            $script:ArmTemplate | Should -Not -BeNullOrEmpty
            $armContent = $script:ArmTemplate | ConvertTo-Json -Depth 20
            $armContent | Should -Match 'supportsHttpsTrafficOnly.*true'
        }

        It "Should have network ACLs deny by default in ARM template" {
            $armContent = $script:ArmTemplate | ConvertTo-Json -Depth 20
            $armContent | Should -Match '"defaultAction".*"Deny"'
        }
    }
}

AfterAll {
    # Delete the temporary resource group (only if it was created)
    if ($script:AzureAvailable -and $script:TestResourceGroup) {
        Write-Host ('Deleting temporary resource group: {0}' -f $script:TestResourceGroup) -ForegroundColor Cyan
        az group delete --name $script:TestResourceGroup --yes --no-wait --output none 2>$null
    }
    Write-Host 'Test cleanup completed' -ForegroundColor Cyan
    if (Test-Path $script:ValidateOutputPath) {
        Write-Host ('Validation output preserved at: {0}' -f $script:ValidateOutputPath) -ForegroundColor Yellow
    }
}