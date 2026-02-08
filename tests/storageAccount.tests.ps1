#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    $ModulePath = Split-Path -Parent $PSScriptRoot
    $TemplatePath = Join-Path $ModulePath "main.bicep"
    $ParametersPath = Join-Path $PSScriptRoot "test.parameters.json"
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
    
    Context "Template Validation" {
        
        It "Should have valid ARM template schema" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            $template = Get-Content $armTemplatePath | ConvertFrom-Json
            
            $template.'$schema' | Should -Not -BeNullOrEmpty
            $template.resources | Should -Not -BeNullOrEmpty
        }
        
        It "Should define storage account module deployment" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            $template = Get-Content $armTemplatePath | ConvertFrom-Json
            
            # For module-based templates, deployments are in resources[0] as properties
            $moduleDeployments = $template.resources[0].PSObject.Properties | Where-Object {
                $_.Value.type -eq "Microsoft.Resources/deployments"
            }
            
            # Should have at least one deployment (storageAccount module)
            $moduleDeployments | Should -Not -BeNullOrEmpty
            $moduleDeployments.Name | Should -Contain 'storageAccount'
        }
        
        It "Should have required parameters defined" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            $template = Get-Content $armTemplatePath | ConvertFrom-Json
            
            # Check for workloadName (used to generate storage account name) and location
            $template.parameters.workloadName | Should -Not -BeNullOrEmpty
            $template.parameters.location | Should -Not -BeNullOrEmpty
        }
        
        It "Should have outputs defined" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            $template = Get-Content $armTemplatePath | ConvertFrom-Json
            
            $template.outputs | Should -Not -BeNullOrEmpty
            $template.outputs.resourceId | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    Write-Host "Test cleanup completed"
}
