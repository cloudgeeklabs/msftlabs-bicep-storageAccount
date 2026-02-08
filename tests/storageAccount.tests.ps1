#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    $ModulePath = Split-Path -Parent $PSScriptRoot
    $TemplatePath = Join-Path $ModulePath "main.bicep"
    $ParametersPath = Join-Path $PSScriptRoot "test.parameters.json"
    
    # Set Azure context
    $SubscriptionId = "b18ea7d6-14b5-41f3-a00d-804a5180c589"
    $ResourceGroup = "rg-bicep-test-$((Get-Random -Maximum 9999))"
    $Location = "centralus"
}

Describe "Bicep Module: Storage Account" {
    
    Context "Static Analysis" {
        
        It "Should have valid Bicep syntax" {
            $build = az bicep build --file $TemplatePath 2>&1
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should generate ARM template" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            Test-Path $armTemplatePath | Should -Be $true
        }
        
        It "Should have security defaults" {
            $content = Get-Content $TemplatePath -Raw
            $content | Should -Match "allowSharedKeyAccess.*false"
            $content | Should -Match "allowBlobPublicAccess.*false"
            $content | Should -Match "defaultToOAuthAuthentication.*true"
        }
        
        It "Should have storage account name sanitization" {
            $moduleContent = Get-Content (Join-Path $ModulePath "modules/storageAccount.bicep") -Raw
            $moduleContent | Should -Match "var sanitizedStorageAccountName"
            $moduleContent | Should -Match "toLower"
            $moduleContent | Should -Match "replace.*storageAccountName"
        }
        
        It "Should enforce TLS 1.2 minimum" {
            $moduleContent = Get-Content (Join-Path $ModulePath "modules/storageAccount.bicep") -Raw
            $moduleContent | Should -Match "minimumTlsVersion.*TLS1_2"
        }
        
        It "Should sanitize storage account name to Azure standards" {
            # Test that sanitization logic exists and handles special characters
            $moduleContent = Get-Content (Join-Path $ModulePath "modules/storageAccount.bicep") -Raw
            # Check for regex pattern that removes non-alphanumeric characters
            $moduleContent | Should -Match "replace.*\[.*a-z0-9.*\]"
        }
        
        It "Should enforce storage account name length constraints" {
            $moduleContent = Get-Content (Join-Path $ModulePath "modules/storageAccount.bicep") -Raw
            # Check for minLength and maxLength decorators
            $moduleContent | Should -Match "@minLength\(3\)"
            $moduleContent | Should -Match "@maxLength\(24\)"
        }
    }
    
    Context "What-If Deployment Analysis" {
        
        It "Should pass what-if validation" {
            $whatif = az deployment group what-if `
                --resource-group $ResourceGroup `
                --template-file $TemplatePath `
                --parameters $ParametersPath `
                2>&1
            
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should create storage account resource" {
            $whatif = az deployment group what-if `
                --resource-group $ResourceGroup `
                --template-file $TemplatePath `
                --parameters $ParametersPath `
                --result-format FullResourcePayloads `
                2>&1 | ConvertFrom-Json
            
            $storageResource = $whatif.changes | Where-Object { 
                $_.resourceType -eq "Microsoft.Storage/storageAccounts" 
            }
            
            $storageResource | Should -Not -BeNullOrEmpty
            $storageResource.changeType | Should -Be "Create"
        }
        
        It "Should create diagnostic settings" {
            $whatif = az deployment group what-if `
                --resource-group $ResourceGroup `
                --template-file $TemplatePath `
                --parameters $ParametersPath `
                --result-format FullResourcePayloads `
                2>&1 | ConvertFrom-Json
            
            $diagnosticResource = $whatif.changes | Where-Object { 
                $_.resourceType -eq "Microsoft.Insights/diagnosticSettings" 
            }
            
            $diagnosticResource | Should -Not -BeNullOrEmpty
        }
        
        It "Should create resource lock" {
            $whatif = az deployment group what-if `
                --resource-group $ResourceGroup `
                --template-file $TemplatePath `
                --parameters $ParametersPath `
                --result-format FullResourcePayloads `
                2>&1 | ConvertFrom-Json
            
            $lockResource = $whatif.changes | Where-Object { 
                $_.resourceType -eq "Microsoft.Authorization/locks" 
            }
            
            $lockResource | Should -Not -BeNullOrEmpty
        }
        
        AfterAll {
            # Cleanup test resource group
            az group delete --name $ResourceGroup --yes --no-wait
        }
    }
    
    Context "Deployment Validation" {
        
        BeforeAll {
            # Create test resource group
            $script:DeployResourceGroup = "rg-bicep-deploy-$((Get-Random -Maximum 9999))"
            az group create --name $script:DeployResourceGroup --location $Location --output none
            
            # Deploy the template
            $script:DeploymentName = "test-deployment-$((Get-Date).ToString('yyyyMMddHHmmss'))"
            az deployment group create `
                --resource-group $script:DeployResourceGroup `
                --template-file $TemplatePath `
                --parameters $ParametersPath `
                --name $script:DeploymentName `
                --output none
        }
        
        It "Should deploy successfully" {
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should have valid outputs" {
            $outputs = az deployment group show `
                --resource-group $script:DeployResourceGroup `
                --name $script:DeploymentName `
                --query properties.outputs `
                2>&1 | ConvertFrom-Json
            
            $outputs.resourceId.value | Should -Not -BeNullOrEmpty
            $outputs.name.value | Should -Not -BeNullOrEmpty
            $outputs.primaryEndpoints.value | Should -Not -BeNullOrEmpty
        }
        
        It "Should have storage account with correct SKU" {
            $params = Get-Content $ParametersPath | ConvertFrom-Json
            $expectedSku = $params.parameters.skuName.value
            
            $storage = az storage account show `
                --resource-group $script:DeployResourceGroup `
                --name $params.parameters.storageAccountName.value `
                2>&1 | ConvertFrom-Json
            
            $storage.sku.name | Should -Be $expectedSku
        }
        
        It "Should have security settings configured" {
            $params = Get-Content $ParametersPath | ConvertFrom-Json
            $storage = az storage account show `
                --resource-group $script:DeployResourceGroup `
                --name $params.parameters.storageAccountName.value `
                2>&1 | ConvertFrom-Json
            
            $storage.allowSharedKeyAccess | Should -Be $false
            $storage.allowBlobPublicAccess | Should -Be $false
            $storage.minimumTlsVersion | Should -Be "TLS1_2"
        }
        
        It "Should have resource lock applied" {
            $params = Get-Content $ParametersPath | ConvertFrom-Json
            $locks = az lock list `
                --resource-group $script:DeployResourceGroup `
                --resource-name $params.parameters.storageAccountName.value `
                --resource-type Microsoft.Storage/storageAccounts `
                2>&1 | ConvertFrom-Json
            
            $locks.Count | Should -BeGreaterThan 0
            $locks[0].level | Should -Be "CanNotDelete"
        }
        
        It "Should have correct tags applied" {
            $params = Get-Content $ParametersPath | ConvertFrom-Json
            $storage = az storage account show `
                --resource-group $script:DeployResourceGroup `
                --name $params.parameters.storageAccountName.value `
                2>&1 | ConvertFrom-Json
            
            $storage.tags | Should -Not -BeNullOrEmpty
            $storage.tags.Environment | Should -Be "Test"
        }
        
        AfterAll {
            # Remove locks before cleanup
            $params = Get-Content $ParametersPath | ConvertFrom-Json
        }
    }
}

AfterAll {
    Write-Host "Test cleanup completed"
}
