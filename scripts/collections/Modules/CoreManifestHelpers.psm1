# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Shared helpers for validating the HVE Core central manifest.

.DESCRIPTION
    Provides reusable object access, path validation, artifact discovery, and
    compatibility helpers for collections/core-manifest.yml validation.
#>

function Get-CoreManifestProperty {
    <#
    .SYNOPSIS
        Gets a named property from a manifest object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }

        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }

    return $null
}

function Get-CoreManifestRawProperty {
    <#
    .SYNOPSIS
        Gets a named property from a manifest object without enumerating list values.
    .DESCRIPTION
        PowerShell unwraps single-item collections when returned from a function.
        Use this helper at call sites that must distinguish a list from a scalar
        (for example, schema checks that reject a string where a list is required).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            $value = $InputObject[$Name]
            if ($null -eq $value) {
                return $null
            }
            return , $value
        }

        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) {
        if ($null -eq $property.Value) {
            return $null
        }
        return , $property.Value
    }

    return $null
}

function Get-CoreManifestKeys {
    <#
    .SYNOPSIS
        Gets property or dictionary keys from a manifest object.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return @()
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        return @($InputObject.Keys | ForEach-Object { [string]$_ })
    }

    return @($InputObject.PSObject.Properties.Name)
}

function ConvertTo-CoreManifestRelativePath {
    <#
    .SYNOPSIS
        Normalizes a manifest path to repository-relative slash form.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Path
    )

    return ($Path.Trim() -replace '\\', '/')
}

function Test-CoreManifestRelativePath {
    <#
    .SYNOPSIS
        Tests whether a manifest path is safely repository-relative.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArtifactPath
    )

    $normalizedPath = ConvertTo-CoreManifestRelativePath -Path $ArtifactPath
    return -not ([System.IO.Path]::IsPathFullyQualified($ArtifactPath) -or
        $normalizedPath -match '^[A-Za-z]:' -or
        $normalizedPath -match '(^|/)\.\.(/|$)' -or
        $normalizedPath -match '^/' -or
        $ArtifactPath -match '^\\')
}

function Read-CoreManifest {
    <#
    .SYNOPSIS
        Reads and parses the central manifest YAML file.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath
    )

    if (-not (Test-Path -Path $ManifestPath -PathType Leaf)) {
        throw "Manifest file '$ManifestPath' does not exist."
    }

    try {
        return Get-Content -Path $ManifestPath -Raw | ConvertFrom-Yaml
    }
    catch {
        throw "Manifest file '$ManifestPath' could not be parsed: $($_.Exception.Message)"
    }
}

function Test-CoreManifestKindPath {
    <#
    .SYNOPSIS
        Validates artifact path conventions for a manifest section.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('agents', 'prompts', 'instructions', 'skills')]
        [string]$Section,

        [Parameter(Mandatory = $true)]
        [string]$ArtifactPath,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [bool]$AllowMissing
    )

    $normalizedPath = ConvertTo-CoreManifestRelativePath -Path $ArtifactPath
    switch ($Section) {
        'agents' {
            if ($normalizedPath -notmatch '^\.github/agents/.+\.agent\.md$') {
                return "agents entry '$ArtifactPath' must be a .github/agents/**/*.agent.md path."
            }
        }
        'prompts' {
            if ($normalizedPath -notmatch '^\.github/prompts/.+\.prompt\.md$') {
                return "prompts entry '$ArtifactPath' must be a .github/prompts/**/*.prompt.md path."
            }
        }
        'instructions' {
            if ($normalizedPath -notmatch '^\.github/instructions/.+\.instructions\.md$') {
                return "instructions entry '$ArtifactPath' must be a .github/instructions/**/*.instructions.md path."
            }
        }
        'skills' {
            if ($normalizedPath -notmatch '^\.github/skills/.+') {
                return "skills entry '$ArtifactPath' must be a .github/skills/** directory path."
            }

            if ($normalizedPath -match '/SKILL\.md$') {
                return "skills entry '$ArtifactPath' must reference the skill directory, not SKILL.md."
            }

            if (-not $AllowMissing) {
                $skillFile = Join-Path -Path (Join-Path -Path $RepoRoot -ChildPath $ArtifactPath) -ChildPath 'SKILL.md'
                if (-not (Test-Path -Path $skillFile -PathType Leaf)) {
                    return "skills entry '$ArtifactPath' must contain SKILL.md."
                }
            }
        }
    }

    return ''
}

function Get-CoreManifestArtifactFiles {
    <#
    .SYNOPSIS
        Discovers current artifact paths that can appear in the manifest.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $paths = [System.Collections.Generic.List[string]]::new()
    $artifactPatterns = @(
        '.github/agents/**/*.agent.md',
        '.github/prompts/**/*.prompt.md',
        '.github/instructions/**/*.instructions.md'
    )

    foreach ($pattern in $artifactPatterns) {
        $absolutePattern = Join-Path -Path $RepoRoot -ChildPath $pattern
        Get-ChildItem -Path $absolutePattern -File -ErrorAction SilentlyContinue | ForEach-Object {
            $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $_.FullName)
            $paths.Add((ConvertTo-CoreManifestRelativePath -Path $relativePath))
        }
    }

    $skillsRoot = Join-Path -Path $RepoRoot -ChildPath '.github/skills'
    if (Test-Path -Path $skillsRoot -PathType Container) {
        Get-ChildItem -Path $skillsRoot -Filter 'SKILL.md' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $_.DirectoryName)
            $paths.Add((ConvertTo-CoreManifestRelativePath -Path $relativePath))
        }
    }

    return @($paths)
}

function ConvertTo-CoreManifestReferenceName {
    <#
    .SYNOPSIS
        Normalizes human-facing manifest reference names for comparison.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Name
    )

    $normalizedName = ($Name.Trim() -replace '\s+', ' ')
    return ($normalizedName -replace '\s+\((exp|pre|preview|experimental|stable)\)$', '').Trim()
}

function Get-CoreManifestAgentDisplayNames {
    <#
    .SYNOPSIS
        Discovers agent display names from leading YAML frontmatter.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $agentNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $agentsRoot = Join-Path -Path $RepoRoot -ChildPath '.github/agents'
    if (-not (Test-Path -Path $agentsRoot -PathType Container)) {
        return @()
    }

    Get-ChildItem -Path $agentsRoot -Filter '*.agent.md' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $content = Get-Content -Path $_.FullName -Raw
        if ($content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            return
        }

        try {
            $frontmatter = ConvertFrom-Yaml -Yaml $Matches[1]
            $name = Get-CoreManifestProperty -InputObject $frontmatter -Name 'name'
            if (-not [string]::IsNullOrWhiteSpace([string]$name)) {
                [void]$agentNames.Add((ConvertTo-CoreManifestReferenceName -Name ([string]$name)))
            }
        }
        catch {
            Write-Verbose "Failed to parse agent frontmatter from $($_.FullName): $($_.Exception.Message)"
        }
    }

    return @($agentNames)
}

function Test-CoreManifestReferenceMetadata {
    <#
    .SYNOPSIS
        Validates optional dependency and handoff metadata for an artifact entry.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Section,

        [Parameter(Mandatory = $true)]
        [string]$ArtifactKey,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Entry,

        [Parameter()]
        [string[]]$KnownAgentNames = @()
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $knownAgentSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($agentName in $KnownAgentNames) {
        if (-not [string]::IsNullOrWhiteSpace($agentName)) {
            [void]$knownAgentSet.Add((ConvertTo-CoreManifestReferenceName -Name $agentName))
        }
    }

    $requires = Get-CoreManifestProperty -InputObject $Entry -Name 'requires'
    if ($null -ne $requires) {
        $requiredAgents = Get-CoreManifestRawProperty -InputObject $requires -Name 'agents'
        if ($null -ne $requiredAgents) {
            if ($requiredAgents -is [string]) {
                $errors.Add("$Section entry '$ArtifactKey' requires.agents must be a list.")
            }
            else {
                foreach ($agentReference in @($requiredAgents)) {
                    if ([string]::IsNullOrWhiteSpace([string]$agentReference)) {
                        $errors.Add("$Section entry '$ArtifactKey' requires.agents contains an empty agent reference.")
                        continue
                    }

                    $normalizedReference = ConvertTo-CoreManifestReferenceName -Name ([string]$agentReference)
                    if ($knownAgentSet.Count -gt 0 -and -not $knownAgentSet.Contains($normalizedReference)) {
                        $warnings.Add("$Section entry '$ArtifactKey' requires.agents references agent '$agentReference' that was not found in agent frontmatter names.")
                    }
                }
            }
        }
    }

    $handoffs = Get-CoreManifestRawProperty -InputObject $Entry -Name 'handoffs'
    if ($null -ne $handoffs) {
        if ($handoffs -is [string] -or $handoffs -is [System.Collections.IDictionary]) {
            $errors.Add("$Section entry '$ArtifactKey' handoffs must be a list.")
        }
        else {
            foreach ($handoff in @($handoffs)) {
                $prompt = Get-CoreManifestProperty -InputObject $handoff -Name 'prompt'
                $agent = Get-CoreManifestProperty -InputObject $handoff -Name 'agent'
                $label = Get-CoreManifestProperty -InputObject $handoff -Name 'label'
                $send = Get-CoreManifestProperty -InputObject $handoff -Name 'send'

                if ([string]::IsNullOrWhiteSpace([string]$prompt)) {
                    $errors.Add("$Section entry '$ArtifactKey' handoffs contains an entry with an empty prompt.")
                }

                if ([string]::IsNullOrWhiteSpace([string]$agent)) {
                    $errors.Add("$Section entry '$ArtifactKey' handoffs contains an entry with an empty agent.")
                }
                else {
                    $normalizedAgent = ConvertTo-CoreManifestReferenceName -Name ([string]$agent)
                    if ($knownAgentSet.Count -gt 0 -and -not $knownAgentSet.Contains($normalizedAgent)) {
                        $warnings.Add("$Section entry '$ArtifactKey' handoffs references agent '$agent' that was not found in agent frontmatter names.")
                    }
                }

                if ([string]::IsNullOrWhiteSpace([string]$label)) {
                    $errors.Add("$Section entry '$ArtifactKey' handoffs contains an entry with an empty label.")
                }

                if ($null -ne $send -and $send -isnot [bool]) {
                    $errors.Add("$Section entry '$ArtifactKey' handoffs send value must be boolean when present.")
                }
            }
        }
    }

    return @{
        Errors   = @($errors)
        Warnings = @($warnings)
    }
}

Export-ModuleMember -Function @(
    'ConvertTo-CoreManifestReferenceName',
    'ConvertTo-CoreManifestRelativePath',
    'Get-CoreManifestAgentDisplayNames',
    'Get-CoreManifestArtifactFiles',
    'Get-CoreManifestKeys',
    'Get-CoreManifestProperty',
    'Get-CoreManifestRawProperty',
    'Read-CoreManifest',
    'Test-CoreManifestKindPath',
    'Test-CoreManifestReferenceMetadata',
    'Test-CoreManifestRelativePath'
)
