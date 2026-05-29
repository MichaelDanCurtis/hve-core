#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module PowerShell-Yaml -ErrorAction Stop
    . $PSScriptRoot/../../collections/Validate-CoreManifest.ps1

    function New-CoreManifestTestRepo {
        param(
            [Parameter(Mandatory = $true)]
            [string]$RootPath
        )

        New-Item -ItemType Directory -Path (Join-Path $RootPath '.github/agents/test') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $RootPath '.github/prompts/test') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $RootPath '.github/instructions/test') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $RootPath '.github/skills/test/test-skill') -Force | Out-Null

        Set-Content -Path (Join-Path $RootPath '.github/agents/test/test.agent.md') -Value "---`ndescription: test agent`n---"
        Set-Content -Path (Join-Path $RootPath '.github/prompts/test/test.prompt.md') -Value "---`ndescription: test prompt`n---"
        Set-Content -Path (Join-Path $RootPath '.github/instructions/test/test.instructions.md') -Value "---`ndescription: test instruction`n---"
        Set-Content -Path (Join-Path $RootPath '.github/skills/test/test-skill/SKILL.md') -Value '# Test skill'
        Set-Content -Path (Join-Path $RootPath 'CHANGELOG.md') -Value '# Changelog'
        Set-Content -Path (Join-Path $RootPath 'release-please-config.json') -Value '{}'
    }

    function New-CoreManifestFixture {
        return [ordered]@{
            schemaVersion = 1
            collections   = [ordered]@{
                'test' = [ordered]@{
                    name        = 'Test'
                    description = 'Test collection'
                }
            }
            agents        = [ordered]@{
                '.github/agents/test/test.agent.md' = [ordered]@{
                    path        = '.github/agents/test/test.agent.md'
                    maturity    = 'stable'
                    collections = @('test')
                }
            }
            prompts       = [ordered]@{
                '.github/prompts/test/test.prompt.md' = [ordered]@{
                    path        = '.github/prompts/test/test.prompt.md'
                    maturity    = 'preview'
                    collections = @('test')
                }
            }
            instructions  = [ordered]@{
                '.github/instructions/test/test.instructions.md' = [ordered]@{
                    path        = '.github/instructions/test/test.instructions.md'
                    maturity    = 'experimental'
                    collections = @('test')
                }
            }
            skills        = [ordered]@{
                '.github/skills/test/test-skill' = [ordered]@{
                    path        = '.github/skills/test/test-skill'
                    maturity    = 'stable'
                    collections = @('test')
                }
            }
            releases      = [ordered]@{
                'test-release' = [ordered]@{
                    channel         = 'stable'
                    includeMaturity = @('stable', 'preview', 'experimental')
                    excludePaths    = @('.github/prompts/test/excluded.prompt.md')
                    artifacts       = @(
                        '.github/agents/test/test.agent.md',
                        '.github/prompts/test/test.prompt.md',
                        '.github/instructions/test/test.instructions.md',
                        '.github/skills/test/test-skill'
                    )
                    whatNew         = [ordered]@{
                        source        = 'release-please-config.json'
                        changelogPath = 'CHANGELOG.md'
                    }
                }
            }
        }
    }

    function Write-CoreManifestFixture {
        param(
            [Parameter(Mandatory = $true)]
            [string]$ManifestPath,

            [Parameter(Mandatory = $true)]
            [object]$Manifest
        )

        New-Item -ItemType Directory -Path (Split-Path -Path $ManifestPath -Parent) -Force | Out-Null
        ConvertTo-Yaml -Data $Manifest | Set-Content -Path $ManifestPath
    }
}

Describe 'Invoke-CoreManifestValidation' {
    BeforeEach {
        $script:repoRoot = Join-Path $TestDrive 'repo'
        $script:manifestPath = Join-Path $script:repoRoot 'collections/core-manifest.yml'
        New-CoreManifestTestRepo -RootPath $script:repoRoot
    }

    It 'Passes for a valid central manifest' {
        $manifest = New-CoreManifestFixture
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'Fails when a required top-level section is missing' {
        $manifest = New-CoreManifestFixture
        $manifest.Remove('schemaVersion')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match "schemaVersion"
    }

    It 'Fails when an artifact key differs from its path' {
        $manifest = New-CoreManifestFixture
        $manifest.agents['.github/agents/test/test.agent.md'].path = '.github/agents/test/other.agent.md'
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match 'must match path'
    }

    It 'Fails for invalid artifact metadata' {
        $manifest = New-CoreManifestFixture
        $manifest.prompts['.github/prompts/test/test.prompt.md'].maturity = 'pilot'
        $manifest.prompts['.github/prompts/test/test.prompt.md'].collections = @('missing')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match "invalid maturity 'pilot'"
        $result.Errors -join "`n" | Should -Match "unknown collection 'missing'"
    }

    It 'Allows missing artifact paths only when maturity is removed' {
        $manifest = New-CoreManifestFixture
        $manifest.agents['.github/agents/test/removed.agent.md'] = [ordered]@{
            path        = '.github/agents/test/removed.agent.md'
            maturity    = 'removed'
            collections = @('test')
        }
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeTrue
    }

    It 'Fails when a non-removed artifact path is missing' {
        $manifest = New-CoreManifestFixture
        $manifest.agents['.github/agents/test/test.agent.md'].path = '.github/agents/test/missing.agent.md'
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match 'does not exist'
    }

    It 'Fails when a release artifact is excluded or not present in artifact sections' {
        $manifest = New-CoreManifestFixture
        $manifest.releases['test-release'].excludePaths = @('.github/agents/test/test.agent.md')
        $manifest.releases['test-release'].artifacts += '.github/agents/test/missing.agent.md'
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match 'lists excluded artifact'
        $result.Errors -join "`n" | Should -Match 'not present in manifest artifact sections'
    }

    It 'Fails when release includeMaturity excludes an artifact maturity' {
        $manifest = New-CoreManifestFixture
        $manifest.releases['test-release'].includeMaturity = @('stable')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match "not included by includeMaturity"
    }

    It 'Allows deprecated release artifacts only with an explicit release flag' {
        $manifest = New-CoreManifestFixture
        $manifest.prompts['.github/prompts/test/test.prompt.md'].maturity = 'deprecated'
        $manifest.releases['test-release'].includeMaturity = @('stable', 'experimental', 'deprecated')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $withoutFlag = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $withoutFlag.Success | Should -BeFalse
        $withoutFlag.Errors -join "`n" | Should -Match 'without allowDeprecated: true'

        $manifest.releases['test-release'].allowDeprecated = $true
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $withFlag = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $withFlag.Success | Should -BeTrue
    }

    It 'Fails when release metadata files are missing' {
        $manifest = New-CoreManifestFixture
        $manifest.releases['test-release'].whatNew.changelogPath = 'missing.md'
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match 'missing.md'
    }
}

Describe 'Export-CoreManifestValidationReport' {
    It 'Writes structured JSON output' {
        $outputPath = Join-Path $TestDrive 'logs/core-manifest-validation-results.json'
        $validationResult = @{
            Success      = $true
            ErrorCount   = 0
            WarningCount = 1
            Errors       = @()
            Warnings     = @('test warning')
        }

        Export-CoreManifestValidationReport -ValidationResult $validationResult -OutputPath $outputPath

        Test-Path -Path $outputPath | Should -BeTrue
        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $report.Success | Should -BeTrue
        $report.ErrorCount | Should -Be 0
        $report.WarningCount | Should -Be 1
        @($report.Warnings)[0] | Should -Be 'test warning'
    }
}