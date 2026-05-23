#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Asserts the SSSC inline state schema preserves exactly the five canonical
    `context` sub-object keys.
#>

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:ssscIdentity = Join-Path $script:repoRoot '.github/instructions/security/sssc-identity.instructions.md'
    $script:expectedKeys = @('ciPlatform','complianceTargets','packageManagers','releaseStrategy','techStack')
}

Describe 'SSSC inline state context preserves five canonical keys' {
    It 'context contains exactly the canonical key set' {
        $content = Get-Content -Path $script:ssscIdentity -Raw
        if ($content -notmatch '(?s)```json\s*\r?\n(\{.*?\})\s*\r?\n```') {
            throw "No ```json block found in $script:ssscIdentity"
        }
        $state = $Matches[1] | ConvertFrom-Json
        $state.context | Should -Not -BeNullOrEmpty
        $observed = $state.context.PSObject.Properties.Name | Sort-Object
        $expected = $script:expectedKeys | Sort-Object
        ($observed -join ',') | Should -Be ($expected -join ',') -Because "context sub-object must contain exactly: $($expected -join ', ')"
    }
}
