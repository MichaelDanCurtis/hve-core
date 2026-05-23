#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Regression guard: every instruction under .github/instructions/security/** and
    .github/instructions/rai-planning/** must use a phase-narrowed `applyTo` glob.
    No file may declare `applyTo: '**'` unless it appears on an explicit allowlist
    matching the Phase 6 audit matrix migration map.
#>

$script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Import-Module powershell-yaml -Force -ErrorAction SilentlyContinue

$script:scanRoots = @(
    (Join-Path $script:repoRoot '.github/instructions/security'),
    (Join-Path $script:repoRoot '.github/instructions/rai-planning')
)

$script:cases = foreach ($root in $script:scanRoots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem -Path $root -Filter '*.md' -Recurse -File | ForEach-Object {
        @{
            Path = $_.FullName
            Rel  = ($_.FullName.Substring($script:repoRoot.Length + 1) -replace '\\','/')
        }
    }
}

Describe 'Phase-narrowed applyTo regression guard' {
    BeforeAll {
        Import-Module powershell-yaml -Force -ErrorAction SilentlyContinue
        $script:applyToAllowlist = @()
        function Test-WorkspaceWideApplyTo {
            param($Value)
            if ($null -eq $Value) { return $false }
            if ($Value -is [string]) { return $Value.Trim() -eq '**' }
            if ($Value -is [System.Collections.IEnumerable]) {
                foreach ($v in $Value) {
                    if (($v -as [string]) -and ($v.Trim() -eq '**')) { return $true }
                }
            }
            return $false
        }
    }

    It 'File <Rel> uses a phase-narrowed applyTo (not workspace-wide)' -ForEach $script:cases {
        $raw = Get-Content -Path $Path -Raw
        if ($raw -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            throw "Missing frontmatter in $Rel"
        }
        $frontmatter = ConvertFrom-Yaml $Matches[1]
        $applyTo = $frontmatter.applyTo
        if (Test-WorkspaceWideApplyTo -Value $applyTo) {
            $script:applyToAllowlist | Should -Contain $Rel -Because "$Rel declares applyTo '**' which is not on the audit-matrix allowlist"
        } else {
            $true | Should -BeTrue
        }
    }
}
