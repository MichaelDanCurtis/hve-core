#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# Discovery-time enumeration so each manifest produces its own It instance.
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$collectionsDir = Join-Path $repoRoot 'collections'
$CollectionFiles = @(Get-ChildItem -Path $collectionsDir -Filter '*.collection.yml' -File | Sort-Object Name)
$CollectionTestCases = @($CollectionFiles | ForEach-Object {
    @{
        CollectionId = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -replace '\.collection$', ''
        FilePath     = $_.FullName
    }
})

BeforeAll {
    Import-Module PowerShell-Yaml -Force
}

Describe 'Collection descriptions.prerelease coverage' {
    It '<CollectionId> exposes a non-whitespace descriptions.prerelease beginning with Experimental:' -TestCases $CollectionTestCases {
        param($CollectionId, $FilePath)

        $manifest = Get-Content -Path $FilePath -Raw | ConvertFrom-Yaml

        $manifest.ContainsKey('descriptions') | Should -BeTrue -Because "collection '$CollectionId' must declare a top-level 'descriptions' map"
        $manifest.descriptions.ContainsKey('prerelease') | Should -BeTrue -Because "collection '$CollectionId' must declare 'descriptions.prerelease'"

        $prerelease = [string]$manifest.descriptions.prerelease
        [string]::IsNullOrWhiteSpace($prerelease) | Should -BeFalse -Because "collection '$CollectionId' must have a non-whitespace 'descriptions.prerelease' value"
        $prerelease | Should -BeLike 'Experimental:*' -Because "collection '$CollectionId' must use the canonical 'Experimental:' prefix"
    }
}
