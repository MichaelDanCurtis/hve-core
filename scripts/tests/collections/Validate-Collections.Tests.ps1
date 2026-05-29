#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../collections/Validate-Collections.ps1
}

Describe 'Test-KindSuffix' {
    It 'Returns empty for valid agent path' {
        $result = Test-KindSuffix -Kind 'agent' -ItemPath '.github/agents/rpi-agent.agent.md' -RepoRoot $TestDrive
        $result | Should -BeNullOrEmpty
    }

    It 'Returns empty for valid prompt path' {
        $result = Test-KindSuffix -Kind 'prompt' -ItemPath '.github/prompts/gen-plan.prompt.md' -RepoRoot $TestDrive
        $result | Should -BeNullOrEmpty
    }

    It 'Returns empty for valid instruction path' {
        $result = Test-KindSuffix -Kind 'instruction' -ItemPath '.github/instructions/csharp.instructions.md' -RepoRoot $TestDrive
        $result | Should -BeNullOrEmpty
    }

    It 'Returns empty for valid skill path with SKILL.md' {
        $skillDir = Join-Path $TestDrive '.github/skills/video-to-gif'
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value '# Skill'

        $result = Test-KindSuffix -Kind 'skill' -ItemPath '.github/skills/video-to-gif' -RepoRoot $TestDrive
        $result | Should -BeNullOrEmpty
    }

    It 'Returns error for invalid agent suffix' {
        $result = Test-KindSuffix -Kind 'agent' -ItemPath '.github/agents/bad.prompt.md' -RepoRoot $TestDrive
        $result | Should -Match "kind 'agent' expects"
    }

    It 'Returns error for invalid prompt suffix' {
        $result = Test-KindSuffix -Kind 'prompt' -ItemPath '.github/prompts/bad.agent.md' -RepoRoot $TestDrive
        $result | Should -Match "kind 'prompt' expects"
    }

    It 'Returns error when SKILL.md missing for skill kind' {
        $emptySkillDir = Join-Path $TestDrive '.github/skills/no-skill'
        New-Item -ItemType Directory -Path $emptySkillDir -Force | Out-Null

        $result = Test-KindSuffix -Kind 'skill' -ItemPath '.github/skills/no-skill' -RepoRoot $TestDrive
        $result | Should -Match "kind 'skill' expects SKILL.md"
    }
}

Describe 'Get-CollectionItemKey' {
    It 'Builds correct composite key' {
        $result = Get-CollectionItemKey -Kind 'agent' -ItemPath '.github/agents/rpi-agent.agent.md'
        $result | Should -Be 'agent|.github/agents/rpi-agent.agent.md'
    }

    It 'Builds key for instruction kind' {
        $result = Get-CollectionItemKey -Kind 'instruction' -ItemPath '.github/instructions/csharp.instructions.md'
        $result | Should -Be 'instruction|.github/instructions/csharp.instructions.md'
    }
}

Describe 'Invoke-CollectionValidation - repo-specific path rejection' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'

        # Create artifact directories and files
        $instrDir = Join-Path $script:repoRoot '.github/instructions'
        $agentsDir = Join-Path $script:repoRoot '.github/agents'
        $sharedDir = Join-Path $instrDir 'shared'
        $hveCoreAgentsDir = Join-Path $agentsDir 'hve-core'

        New-Item -ItemType Directory -Path $instrDir -Force | Out-Null
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $sharedDir -Force | Out-Null
        New-Item -ItemType Directory -Path $hveCoreAgentsDir -Force | Out-Null

        # Root-level (repo-specific) files
        Set-Content -Path (Join-Path $instrDir 'workflows.instructions.md') -Value '---\ndescription: repo-specific\n---'
        Set-Content -Path (Join-Path $agentsDir 'internal.agent.md') -Value '---\ndescription: repo-specific agent\n---'

        # Subdirectory (collection-scoped) files
        Set-Content -Path (Join-Path $sharedDir 'hve-core-location.instructions.md') -Value '---\ndescription: shared\n---'
        Set-Content -Path (Join-Path $hveCoreAgentsDir 'rpi-agent.agent.md') -Value '---\ndescription: distributable agent\n---'
    }

    BeforeEach {
        # Clear collection files between tests to prevent cross-contamination
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Fails validation for root-level instruction' {
        $manifest = [ordered]@{
            id          = 'test-reject-instr'
            name        = 'Test Reject Instruction'
            description = 'Tests repo-specific instruction rejection'
            items       = @(
                [ordered]@{
                    path = '.github/instructions/workflows.instructions.md'
                    kind = 'instruction'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-reject-instr.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Passes validation for instruction in subdirectory' {
        $manifest = [ordered]@{
            id          = 'test-allow-location'
            name        = 'Test Allow Location'
            description = 'Tests that subdirectory instructions are allowed'
            items       = @(
                [ordered]@{
                    path = '.github/instructions/shared/hve-core-location.instructions.md'
                    kind = 'instruction'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-allow-location.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Fails validation for root-level agent' {
        $manifest = [ordered]@{
            id          = 'test-reject-agent'
            name        = 'Test Reject Agent'
            description = 'Tests repo-specific agent rejection'
            items       = @(
                [ordered]@{
                    path = '.github/agents/internal.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-reject-agent.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Passes validation for agent in subdirectory' {
        $manifest = [ordered]@{
            id          = 'test-allow-agent'
            name        = 'Test Allow Agent'
            description = 'Tests that subdirectory agents pass'
            items       = @(
                [ordered]@{
                    path = '.github/agents/hve-core/rpi-agent.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-allow-agent.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }
}

Describe 'Invoke-CollectionValidation - collection-level maturity' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'maturity-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'

        # Create a valid artifact for items to reference
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'test.agent.md') -Value '---\ndescription: test agent\n---'
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Passes validation for collection with maturity: experimental' {
        $manifest = [ordered]@{
            id          = 'test-maturity-experimental'
            name        = 'Test'
            description = 'Tests experimental maturity'
            maturity    = 'experimental'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                    maturity = 'experimental'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-maturity-experimental.collection.yml') -Value $yaml
        Set-Content -Path (Join-Path $script:repoRoot '.github/agents/test/test.agent.md') -Value "---`nname: Test(exp)`ndescription: test agent`n---"

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Passes validation for collection with maturity: stable' {
        $manifest = [ordered]@{
            id          = 'test-maturity-stable'
            name        = 'Test'
            description = 'Tests stable maturity'
            maturity    = 'stable'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-maturity-stable.collection.yml') -Value $yaml
        Set-Content -Path (Join-Path $script:repoRoot '.github/agents/test/test.agent.md') -Value "---`nname: Test`ndescription: test agent`n---"

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Passes validation for collection with maturity: preview' {
        $manifest = [ordered]@{
            id          = 'test-maturity-preview'
            name        = 'Test'
            description = 'Tests preview maturity'
            maturity    = 'preview'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                    maturity = 'preview'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-maturity-preview.collection.yml') -Value $yaml
        Set-Content -Path (Join-Path $script:repoRoot '.github/agents/test/test.agent.md') -Value "---`nname: Test(pre)`ndescription: test agent`n---"

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Passes validation for collection with maturity: deprecated' {
        $manifest = [ordered]@{
            id          = 'test-maturity-deprecated'
            name        = 'Test'
            description = 'Tests deprecated maturity'
            maturity    = 'deprecated'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-maturity-deprecated.collection.yml') -Value $yaml
        Set-Content -Path (Join-Path $script:repoRoot '.github/agents/test/test.agent.md') -Value "---`nname: Test`ndescription: test agent`n---"

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Fails validation for collection with invalid maturity: beta' {
        $manifest = [ordered]@{
            id          = 'test-maturity-beta'
            name        = 'Test'
            description = 'Tests invalid maturity'
            maturity    = 'beta'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-maturity-beta.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Passes validation for collection with omitted maturity' {
        $manifest = [ordered]@{
            id          = 'test-maturity-omitted'
            name        = 'Test'
            description = 'Tests omitted maturity'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-maturity-omitted.collection.yml') -Value $yaml
        Set-Content -Path (Join-Path $script:repoRoot '.github/agents/test/test.agent.md') -Value "---`nname: Test`ndescription: test agent`n---"

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }
}

Describe 'Invoke-CollectionValidation - collection-to-folder name consistency' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'folder-consistency-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'

        # Matching folder structure
        $matchDir = Join-Path $script:repoRoot '.github/agents/my-collection'
        New-Item -ItemType Directory -Path $matchDir -Force | Out-Null
        Set-Content -Path (Join-Path $matchDir 'match.agent.md') -Value '---\ndescription: matching agent\n---'

        # Mismatched folder structure
        $mismatchDir = Join-Path $script:repoRoot '.github/agents/wrong-folder'
        New-Item -ItemType Directory -Path $mismatchDir -Force | Out-Null
        Set-Content -Path (Join-Path $mismatchDir 'mismatch.agent.md') -Value '---\ndescription: mismatched agent\n---'

        # Shared folder structure
        $sharedDir = Join-Path $script:repoRoot '.github/instructions/shared'
        New-Item -ItemType Directory -Path $sharedDir -Force | Out-Null
        Set-Content -Path (Join-Path $sharedDir 'shared.instructions.md') -Value '---\ndescription: shared instruction\n---'

        # rai-planning sub-domain folder structure (shared across themed collections)
        $raiPlanningDir = Join-Path $script:repoRoot '.github/instructions/rai-planning'
        New-Item -ItemType Directory -Path $raiPlanningDir -Force | Out-Null
        Set-Content -Path (Join-Path $raiPlanningDir 'rai.instructions.md') -Value '---\ndescription: rai-planning instruction\n---'

        # hve-core folder structure (cross-collection reference allowed without warning)
        $hveCoreDir = Join-Path $script:repoRoot '.github/agents/hve-core'
        New-Item -ItemType Directory -Path $hveCoreDir -Force | Out-Null
        Set-Content -Path (Join-Path $hveCoreDir 'core.agent.md') -Value '---\ndescription: hve-core agent\n---'
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Passes when collection-id matches folder name' {
        Mock Write-Host {}

        $manifest = [ordered]@{
            id          = 'my-collection'
            name        = 'My Collection'
            description = 'Collection with matching folder'
            items       = @(
                [ordered]@{
                    path = '.github/agents/my-collection/match.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'my-collection.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Not -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection.*my-collection'
        }
    }

    It 'Warns but does not fail when collection-id does not match folder name' {
        Mock Write-Host {}

        $manifest = [ordered]@{
            id          = 'my-collection'
            name        = 'My Collection'
            description = 'Collection with mismatched folder'
            items       = @(
                [ordered]@{
                    path = '.github/agents/wrong-folder/mismatch.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'my-collection.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection.*wrong-folder'
        }
    }

    It 'Allows items from hve-core/ folder in any collection' {
        Mock Write-Host {}

        $manifest = [ordered]@{
            id          = 'my-collection'
            name        = 'My Collection'
            description = 'Collection referencing hve-core item'
            items       = @(
                [ordered]@{
                    path = '.github/agents/hve-core/core.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'my-collection.collection.yml') -Value $yaml

        # Register hve-core as a known collection ID (mirrors real-world hve-core.collection.yml)
        $hveCoreManifest = [ordered]@{
            id          = 'hve-core'
            name        = 'HVE Core'
            description = 'HVE Core collection'
            items       = @()
        }
        $hveYaml = ConvertTo-Yaml -Data $hveCoreManifest
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core.collection.yml') -Value $hveYaml
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core.collection.md') -Value '# HVE Core'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Not -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection'
        }
    }

    It 'Allows items from shared/ folder in any collection' {
        Mock Write-Host {}

        $manifest = [ordered]@{
            id          = 'my-collection'
            name        = 'My Collection'
            description = 'Collection referencing shared item'
            items       = @(
                [ordered]@{
                    path = '.github/instructions/shared/shared.instructions.md'
                    kind = 'instruction'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'my-collection.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Not -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection'
        }
    }

    It 'Allows items from rai-planning/ folder in any collection' {
        Mock Write-Host {}

        $manifest = [ordered]@{
            id          = 'my-collection'
            name        = 'My Collection'
            description = 'Collection referencing rai-planning item'
            items       = @(
                [ordered]@{
                    path = '.github/instructions/rai-planning/rai.instructions.md'
                    kind = 'instruction'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'my-collection.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Not -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection'
        }
    }

    It 'Allows hve-core-all to reference items from any folder' {
        Mock Write-Host {}

        $manifest = [ordered]@{
            id          = 'hve-core-all'
            name        = 'HVE Core All'
            description = 'Aggregate collection'
            items       = @(
                [ordered]@{
                    path = '.github/agents/my-collection/match.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                },
                [ordered]@{
                    path = '.github/agents/wrong-folder/mismatch.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                },
                [ordered]@{
                    path = '.github/instructions/shared/shared.instructions.md'
                    kind = 'instruction'
                    maturity = 'stable'
                },
                [ordered]@{
                    path = '.github/instructions/rai-planning/rai.instructions.md'
                    kind = 'instruction'
                    maturity = 'stable'
                },
                [ordered]@{
                    path = '.github/agents/hve-core/core.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value $yaml
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Not -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection'
        }
    }

    It 'Emits warning output for mismatched folder name without failing' {
        Mock Write-Host {}

        $manifest = [ordered]@{
            id          = 'my-collection'
            name        = 'My Collection'
            description = 'Mismatch for warning output test'
            items       = @(
                [ordered]@{
                    path = '.github/agents/wrong-folder/mismatch.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'my-collection.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        # Advisory warning uses Write-Host WARN; validation still passes
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection.*wrong-folder'
        }
    }
}

Describe 'Invoke-CollectionValidation - error paths' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'error-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'

        # Create valid artifacts for reference
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'a.agent.md') -Value '---\ndescription: agent a\n---'
        Set-Content -Path (Join-Path $agentsDir 'b.agent.md') -Value '---\ndescription: agent b\n---'

        $instrDir = Join-Path $script:repoRoot '.github/instructions/test'
        New-Item -ItemType Directory -Path $instrDir -Force | Out-Null
        Set-Content -Path (Join-Path $instrDir 'test.instructions.md') -Value '---\ndescription: test\n---'
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Returns success with zero collections when directory is empty' {
        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.CollectionCount | Should -Be 0
    }

    It 'Fails when required field is missing' {
        $yaml = @"
name: No ID Collection
description: Missing id field
items:
  - path: .github/agents/test/a.agent.md
    kind: agent
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'no-id.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails for invalid id format' {
        $manifest = [ordered]@{
            id          = 'INVALID_ID!'
            name        = 'Bad ID'
            description = 'Invalid id format'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'bad-id.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails for duplicate ids across collections' {
        $manifest = [ordered]@{
            id          = 'dup-id'
            name        = 'First'
            description = 'First collection'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'dup1.collection.yml') -Value $yaml
        Set-Content -Path (Join-Path $script:collectionsDir 'dup2.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails when item path does not exist' {
        $manifest = [ordered]@{
            id          = 'missing-path'
            name        = 'Missing'
            description = 'Item path missing'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/nonexistent.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'missing-path.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails when item has no kind' {
        $yaml = @"
id: no-kind
name: No Kind
description: Item missing kind
items:
  - path: .github/agents/test/a.agent.md
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'no-kind.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails for invalid item maturity' {
        $manifest = [ordered]@{
            id          = 'bad-item-mat'
            name        = 'Bad Item Maturity'
            description = 'Item with invalid maturity'
            items       = @(
                [ordered]@{
                    path     = '.github/agents/test/a.agent.md'
                    kind     = 'agent'
                    maturity = 'alpha'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'bad-item-mat.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails for kind-suffix mismatch' {
        $manifest = [ordered]@{
            id          = 'suffix-mismatch'
            name        = 'Suffix Mismatch'
            description = 'Agent path with wrong suffix'
            items       = @(
                [ordered]@{
                    path = '.github/instructions/test/test.instructions.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'suffix-mismatch.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails for instruction kind with wrong suffix' {
        $manifest = [ordered]@{
            id          = 'instr-suffix'
            name        = 'Instruction Suffix'
            description = 'Instruction item with agent suffix'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'instruction'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'instr-suffix.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Detects duplicate artifact keys at distinct paths' {
        # Two agents at different paths that resolve to the same artifact key
        $agentsDir2 = Join-Path $script:repoRoot '.github/agents/other'
        New-Item -ItemType Directory -Path $agentsDir2 -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir2 'a.agent.md') -Value '---\ndescription: same name\n---'

        $manifest = [ordered]@{
            id          = 'dup-artifact'
            name        = 'Dup Artifact'
            description = 'Same artifact key from different paths'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                },
                [ordered]@{
                    path = '.github/agents/other/a.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'dup-artifact.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Detects shared item missing canonical entry' {
        # Two collections share the same item but neither is hve-core-all;
        # hve-core-all exists but does not include a.agent.md - Check 4 fires.
        $manifest1 = [ordered]@{
            id          = 'share-one'
            name        = 'Share One'
            description = 'First sharer'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $manifest2 = [ordered]@{
            id          = 'share-two'
            name        = 'Share Two'
            description = 'Second sharer'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $canonical = [ordered]@{
            id          = 'hve-core-all'
            name        = 'All'
            description = 'Canonical - missing a.agent.md'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/b.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                },
                [ordered]@{
                    path = '.github/instructions/test/test.instructions.md'
                    kind = 'instruction'
                    maturity = 'stable'
                }
            )
        }
        $yaml1 = ConvertTo-Yaml -Data $manifest1
        $yaml2 = ConvertTo-Yaml -Data $manifest2
        $yaml3 = ConvertTo-Yaml -Data $canonical
        Set-Content -Path (Join-Path $script:collectionsDir 'share-one.collection.yml') -Value $yaml1
        Set-Content -Path (Join-Path $script:collectionsDir 'share-two.collection.yml') -Value $yaml2
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value $yaml3
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Detects maturity conflict with canonical collection' {
        # hve-core-all has the item as stable, another collection has it as experimental
        $canonical = [ordered]@{
            id          = 'hve-core-all'
            name        = 'All'
            description = 'Canonical collection'
            items       = @(
                [ordered]@{
                    path     = '.github/agents/test/a.agent.md'
                    kind     = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $other = [ordered]@{
            id          = 'conflict-col'
            name        = 'Conflict'
            description = 'Conflicting maturity'
            items       = @(
                [ordered]@{
                    path     = '.github/agents/test/a.agent.md'
                    kind     = 'agent'
                    maturity = 'experimental'
                }
            )
        }
        $yaml1 = ConvertTo-Yaml -Data $canonical
        $yaml2 = ConvertTo-Yaml -Data $other
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value $yaml1
        Set-Content -Path (Join-Path $script:collectionsDir 'conflict-col.collection.yml') -Value $yaml2

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Detects inherited maturity conflict with canonical collection' {
        $canonical = [ordered]@{
            id          = 'hve-core-all'
            name        = 'All'
            description = 'Canonical collection'
            items       = @(
                [ordered]@{
                    path     = '.github/agents/test/a.agent.md'
                    kind     = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $other = [ordered]@{
            id          = 'conflict-col'
            name        = 'Conflict'
            description = 'Conflicting maturity'
            maturity    = 'experimental'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $yaml1 = ConvertTo-Yaml -Data $canonical
        $yaml2 = ConvertTo-Yaml -Data $other
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value $yaml1
        Set-Content -Path (Join-Path $script:collectionsDir 'conflict-col.collection.yml') -Value $yaml2

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Accepts inherited maturity when it matches canonical collection' {
        $leakedDir = Join-Path $script:repoRoot '.github/agents/other'
        if (Test-Path $leakedDir) { Remove-Item -Path $leakedDir -Recurse -Force }

        $canonical = [ordered]@{
            id          = 'hve-core-all'
            name        = 'All'
            description = 'Canonical collection'
            items       = @(
                [ordered]@{
                    path     = '.github/agents/test/a.agent.md'
                    kind     = 'agent'
                    maturity = 'experimental'
                },
                [ordered]@{
                    path = '.github/agents/test/b.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                },
                [ordered]@{
                    path = '.github/instructions/test/test.instructions.md'
                    kind = 'instruction'
                    maturity = 'stable'
                }
            )
        }
        $other = [ordered]@{
            id          = 'experimental-col'
            name        = 'Experimental'
            description = 'Experimental maturity'
            maturity    = 'experimental'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                    maturity = 'experimental'
                }
            )
        }
        $yaml1 = ConvertTo-Yaml -Data $canonical
        $yaml2 = ConvertTo-Yaml -Data $other
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value $yaml1
        Set-Content -Path (Join-Path $script:collectionsDir 'experimental-col.collection.yml') -Value $yaml2
        Set-Content -Path (Join-Path $script:repoRoot '.github/agents/test/a.agent.md') -Value "---`nname: A(exp)`ndescription: agent a`n---"

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Lets item maturity override collection maturity' {
        $leakedDir = Join-Path $script:repoRoot '.github/agents/other'
        if (Test-Path $leakedDir) { Remove-Item -Path $leakedDir -Recurse -Force }

        $canonical = [ordered]@{
            id          = 'hve-core-all'
            name        = 'All'
            description = 'Canonical collection'
            items       = @(
                [ordered]@{
                    path     = '.github/agents/test/a.agent.md'
                    kind     = 'agent'
                    maturity = 'preview'
                },
                [ordered]@{
                    path = '.github/agents/test/b.agent.md'
                    kind = 'agent'
                    maturity = 'stable'
                },
                [ordered]@{
                    path = '.github/instructions/test/test.instructions.md'
                    kind = 'instruction'
                    maturity = 'stable'
                }
            )
        }
        $other = [ordered]@{
            id          = 'override-col'
            name        = 'Override'
            description = 'Item maturity override'
            maturity    = 'experimental'
            items       = @(
                [ordered]@{
                    path     = '.github/agents/test/a.agent.md'
                    kind     = 'agent'
                    maturity = 'preview'
                }
            )
        }
        $yaml1 = ConvertTo-Yaml -Data $canonical
        $yaml2 = ConvertTo-Yaml -Data $other
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value $yaml1
        Set-Content -Path (Join-Path $script:collectionsDir 'override-col.collection.yml') -Value $yaml2
        Set-Content -Path (Join-Path $script:repoRoot '.github/agents/test/a.agent.md') -Value "---`nname: A(pre)`ndescription: agent a`n---"

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }
}

Describe 'Invoke-CollectionValidation - new checks' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'new-checks-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'

        # Standard artifact - used by most tests
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'a.agent.md') -Value '---' -Force

        # Orphan artifact - on disk but not necessarily in manifests
        $orphanDir = Join-Path $script:repoRoot '.github/agents/orphan'
        New-Item -ItemType Directory -Path $orphanDir -Force | Out-Null
        Set-Content -Path (Join-Path $orphanDir 'orphan.agent.md') -Value '---' -Force
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) { Remove-Item -Path $script:collectionsDir -Recurse -Force }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null

        # Reset agent dirs to pristine state - prevents artifact leakage between tests
        $agentsBaseDir = Join-Path $script:repoRoot '.github/agents'
        if (Test-Path $agentsBaseDir) { Remove-Item -Path $agentsBaseDir -Recurse -Force }
        New-Item -ItemType Directory -Path (Join-Path $agentsBaseDir 'test') -Force | Out-Null
        Set-Content -Path (Join-Path $agentsBaseDir 'test/a.agent.md') -Value '---' -Force
        New-Item -ItemType Directory -Path (Join-Path $agentsBaseDir 'orphan') -Force | Out-Null
        Set-Content -Path (Join-Path $agentsBaseDir 'orphan/orphan.agent.md') -Value '---' -Force
    }

    # Check 3: companion .collection.md

    It 'Warns but passes when .collection.md companion is missing' {
        $manifest = [ordered]@{
            id = 'no-companion'; name = 'No Companion'; description = 'Missing companion md'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'no-companion.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical'
            items = @(
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'Passes cleanly when .collection.md companion is present' {
        $manifest = [ordered]@{
            id = 'has-companion'; name = 'Has Companion'; description = 'With md'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'has-companion.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        Set-Content -Path (Join-Path $script:collectionsDir 'has-companion.collection.md') -Value '# Has Companion'
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical'
            items = @(
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    # Check 2: intra-collection duplicate

    It 'Fails when the same item appears twice in one collection' {
        $manifest = [ordered]@{
            id = 'intra-dup'; name = 'Intra Dup'; description = 'Dup item'
            items = @(
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'intra-dup.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Passes when all items in a collection are distinct' {
        $agentsDir2 = Join-Path $script:repoRoot '.github/agents/test2'
        New-Item -ItemType Directory -Path $agentsDir2 -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir2 'b.agent.md') -Value '---' -Force

        $manifest = [ordered]@{
            id = 'distinct-items'; name = 'Distinct'; description = 'Distinct items'
            items = @(
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/test2/b.agent.md'; kind = 'agent'; maturity = 'stable' }
            )
        }
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical'
            items = @(
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/test2/b.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'distinct-items.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        Set-Content -Path (Join-Path $script:collectionsDir 'distinct-items.collection.md') -Value '# Distinct'
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    # Check 4: hve-core-all coverage

    It 'Fails when a themed collection item is absent from hve-core-all' {
        $manifest = [ordered]@{
            id = 'themed-only'; name = 'Themed Only'; description = 'Item not in hve-core-all'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        # Canonical exists but does NOT include a.agent.md - only orphan - so Check 4 fires
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical - missing themed item'
            items = @([ordered]@{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'themed-only.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        Set-Content -Path (Join-Path $script:collectionsDir 'themed-only.collection.md') -Value '# Themed'
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Passes when all themed items are present in hve-core-all' {
        $themed = [ordered]@{
            id = 'themed-covered'; name = 'Themed Covered'; description = 'Covered by canonical'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical'
            items = @(
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'themed-covered.collection.yml') -Value (ConvertTo-Yaml -Data $themed)
        Set-Content -Path (Join-Path $script:collectionsDir 'themed-covered.collection.md') -Value '# Themed Covered'
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    # Check 1: orphan detection

    It 'Fails when an on-disk artifact is absent from hve-core-all' {
        # manifest and canonical cover a.agent.md but NOT orphan/orphan.agent.md
        $manifest = [ordered]@{
            id = 'partial-coverage'; name = 'Partial'; description = 'Missing orphan'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical - missing orphan'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'partial-coverage.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        Set-Content -Path (Join-Path $script:collectionsDir 'partial-coverage.collection.md') -Value '# Partial'
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Warns but passes when artifact is in hve-core-all but not in any themed collection' {
        # Themed covers only a.agent.md; canonical covers both - orphan is canonical-only
        $themed = [ordered]@{
            id = 'themed-partial'; name = 'Themed Partial'; description = 'Missing orphan in themed'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical - covers orphan'
            items = @(
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'themed-partial.collection.yml') -Value (ConvertTo-Yaml -Data $themed)
        Set-Content -Path (Join-Path $script:collectionsDir 'themed-partial.collection.md') -Value '# Themed Partial'
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }
}

Describe 'Invoke-CollectionValidation - marker validation' -Tag 'Unit' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'marker-validation'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'
        # Create artifact directories
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'a.agent.md') -Value '---' -Force
        $orphanDir = Join-Path $script:repoRoot '.github/agents/orphan'
        New-Item -ItemType Directory -Path $orphanDir -Force | Out-Null
        Set-Content -Path (Join-Path $orphanDir 'orphan.agent.md') -Value '---' -Force
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Passes when collection.md has valid matched marker pairs' {
        $manifest = [ordered]@{
            id = 'valid-markers'; name = 'Valid Markers'; description = 'Matched markers'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'valid-markers.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        $mdContent = @"
# Valid Markers

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->
Generated content.
<!-- END AUTO-GENERATED ARTIFACTS -->
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'valid-markers.collection.md') -Value $mdContent
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical'
            items = @(
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'Warns but passes when begin marker exists without end marker' {
        $manifest = [ordered]@{
            id = 'begin-only'; name = 'Begin Only'; description = 'Missing end'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'begin-only.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        $mdContent = @"
# Begin Only

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->
Content without end marker.
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'begin-only.collection.md') -Value $mdContent
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical'
            items = @(
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'Warns but passes when end marker exists without begin marker' {
        $manifest = [ordered]@{
            id = 'end-only'; name = 'End Only'; description = 'Missing begin'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'end-only.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        $mdContent = @"
# End Only

Content without begin marker.
<!-- END AUTO-GENERATED ARTIFACTS -->
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'end-only.collection.md') -Value $mdContent
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical'
            items = @(
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'Does not warn when collection.md has no markers (backward compat)' {
        $manifest = [ordered]@{
            id = 'no-markers'; name = 'No Markers'; description = 'Legacy no markers'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'no-markers.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        Set-Content -Path (Join-Path $script:collectionsDir 'no-markers.collection.md') -Value '# No Markers - legacy content without any markers'
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical'
            items = @(
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'Warns but passes when markers appear in wrong order' {
        $manifest = [ordered]@{
            id = 'reversed'; name = 'Reversed'; description = 'Wrong order'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'reversed.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        $mdContent = @"
# Reversed

<!-- END AUTO-GENERATED ARTIFACTS -->
Content.
<!-- BEGIN AUTO-GENERATED ARTIFACTS -->
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'reversed.collection.md') -Value $mdContent
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical'
            items = @(
                [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                [ordered]@{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }
}

Describe 'Collection validation JSON reporting' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop
        $script:repoRoot = Join-Path $TestDrive 'json-reporting-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'a.agent.md') -Value '---' -Force
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Includes structured validation results in the return payload' {
        $yaml = @"
name: No ID Collection
description: Missing id field
items:
  - path: .github/agents/test/a.agent.md
    kind: agent
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'no-id.collection.yml') -Value $yaml
        Set-Content -Path (Join-Path $script:collectionsDir 'no-id.collection.md') -Value '# No ID' -Force

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $result.Success | Should -BeFalse
        $result.Results | Should -Not -BeNullOrEmpty
        $missingField = @($result.Results | Where-Object { $_.ErrorType -eq 'MissingRequiredField' })
        $missingField | Should -Not -BeNullOrEmpty
        $missingField[0].Collection | Should -Be 'no-id'
        $missingField[0].Message | Should -Match "missing required field 'id'"
    }

    It 'Exports JSON report with expected schema' {
        $manifest = [ordered]@{
            id          = 'hve-core-all'
            name        = 'All'
            description = 'Canonical'
            items       = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $outputPath = Join-Path $TestDrive 'collection-validation-results.json'
        Export-CollectionValidationReport -ValidationResult $result -OutputPath $outputPath
        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json

        $report.Timestamp | Should -Not -BeNullOrEmpty
        $report.TotalCollections | Should -Be 1
        $report.ErrorCount | Should -Be 0
        $report.PSObject.Properties.Name | Should -Contain 'Results'
        $report.Results | ForEach-Object {
            $_.PSObject.Properties.Name | Should -Contain 'Collection'
            $_.PSObject.Properties.Name | Should -Contain 'Severity'
            $_.PSObject.Properties.Name | Should -Contain 'ErrorType'
            $_.PSObject.Properties.Name | Should -Contain 'Message'
        }
    }

    It 'Differentiates Severity between warnings and errors in results' {
        $yaml = @"
name: No ID Collection
description: Missing id field
items:
  - path: .github/agents/test/a.agent.md
    kind: agent
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'no-id.collection.yml') -Value $yaml

        # Also create a valid companion-less collection to generate a Warning alongside the Error
        $validYaml = @"
id: some-collection
name: Some Collection
description: Valid collection missing companion md
items:
  - path: .github/agents/test/a.agent.md
    kind: agent
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'some-collection.collection.yml') -Value $validYaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $errors = @($result.Results | Where-Object { $_.Severity -eq 'Error' })
        $warnings = @($result.Results | Where-Object { $_.Severity -eq 'Warning' })

        $errors | Should -Not -BeNullOrEmpty
        $warnings | Should -Not -BeNullOrEmpty
        $errors[0].ErrorType | Should -Be 'MissingRequiredField'
        $warnings | Where-Object { $_.ErrorType -eq 'MissingCompanionCollectionMd' } | Should -Not -BeNullOrEmpty
    }

    It 'Creates output directory when it does not exist' {
        $manifest = [ordered]@{
            id          = 'hve-core-all'
            name        = 'All'
            description = 'Canonical'
            items       = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $newDir = Join-Path $TestDrive 'nonexistent-logs-dir'
        $outputPath = Join-Path $newDir 'results.json'

        Test-Path $newDir | Should -BeFalse
        Export-CollectionValidationReport -ValidationResult $result -OutputPath $outputPath
        Test-Path $newDir | Should -BeTrue
        Test-Path $outputPath | Should -BeTrue
    }

    It 'Captures multiple distinct ErrorType values in a single run' {
        $yaml = @"
id: multi-error
name: Multi Error Collection
description: Has both a path-not-found and a missing-kind error
items:
  - path: .github/agents/test/nonexistent.agent.md
    kind: agent
  - path: .github/agents/test/a.agent.md
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'multi-error.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $result.Success | Should -BeFalse
        $errorTypes = $result.Results | Select-Object -ExpandProperty ErrorType
        $errorTypes | Should -Contain 'PathNotFound'
        $errorTypes | Should -Contain 'MissingItemKind'
    }

    It 'Returns a Results key even when a collection passes validation' {
        $manifest = [ordered]@{
            id          = 'hve-core-all'
            name        = 'All'
            description = 'Canonical'
            items       = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $result.Success | Should -BeTrue
        $result.Keys | Should -Contain 'Results'
    }
}

Describe 'Invoke-CollectionValidation - MaturityConflict diagnostic' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'maturity-conflict-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'

        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'a.agent.md') -Value '---'
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Fires MaturityConflict when canonical and themed effective maturity differ' {
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'experimental' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $themed = [ordered]@{
            id = 'themed-stable'; name = 'Themed'; description = 'Themed stable'
            maturity = 'stable'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'themed-stable.collection.yml') -Value (ConvertTo-Yaml -Data $themed)

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $result.Success | Should -BeFalse
        $conflicts = @($result.Results | Where-Object { $_.ErrorType -eq 'MaturityConflict' })
        $conflicts.Count | Should -BeGreaterOrEqual 1
        $conflicts[0].Message | Should -Match 'expected'
        $conflicts[0].Message | Should -Match 'themed-stable\.collection\.yml'
    }

    It 'Does not fire MaturityConflict when canonical and themed maturity align' {
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'experimental' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        $themed = [ordered]@{
            id = 'themed-exp'; name = 'Themed'; description = 'Themed exp'
            maturity = 'experimental'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'experimental' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'themed-exp.collection.yml') -Value (ConvertTo-Yaml -Data $themed)

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'MaturityConflict' }).Count | Should -Be 0
    }

    It 'Item-level maturity overrides collection-level when computing effective maturity' {
        $canonical = [ordered]@{
            id = 'hve-core-all'; name = 'All'; description = 'Canonical'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value (ConvertTo-Yaml -Data $canonical)
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.md') -Value '# All'

        # Themed has collection-level experimental but item-level stable override
        $themed = [ordered]@{
            id = 'themed-override'; name = 'Themed'; description = 'Themed override'
            maturity = 'experimental'
            items = @([ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'themed-override.collection.yml') -Value (ConvertTo-Yaml -Data $themed)

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'MaturityConflict' }).Count | Should -Be 0
    }
}

Describe 'Invoke-CollectionValidation - AgentMaturityLabelMismatch diagnostic' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'maturity-label-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'
        $script:agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $script:agentsDir -Force | Out-Null

        function script:Set-AgentFrontmatter {
            param(
                [Parameter(Mandatory)] [string]$Name,
                [switch]$OmitName
            )
            $path = Join-Path $script:agentsDir 'a.agent.md'
            if ($OmitName) {
                Set-Content -Path $path -Value "---`ndescription: test agent`n---"
            } else {
                Set-Content -Path $path -Value "---`nname: $Name`ndescription: test agent`n---"
            }
        }

        function script:Set-CollectionManifest {
            param(
                [Parameter(Mandatory)] [string]$Id,
                [string]$Maturity,
                [string]$ItemMaturity
            )
            $itemMat = if ($ItemMaturity) { $ItemMaturity } elseif ($Maturity) { $Maturity } else { 'stable' }
            $item = [ordered]@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = $itemMat }
            $manifest = [ordered]@{
                id          = $Id
                name        = 'Test'
                description = 'maturity label test'
                items       = @($item)
            }
            if ($Maturity) { $manifest['maturity'] = $Maturity }
            $yaml = ConvertTo-Yaml -Data $manifest
            Set-Content -Path (Join-Path $script:collectionsDir "$Id.collection.yml") -Value $yaml
            Set-Content -Path (Join-Path $script:collectionsDir "$Id.collection.md") -Value "# $Id"
        }
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    # --- Step 2.1 positive cases ---

    It 'Fires AgentMaturityLabelMismatch for experimental agent missing (exp) suffix' {
        Set-AgentFrontmatter -Name 'Test'
        Set-CollectionManifest -Id 'exp-missing' -Maturity 'experimental'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $mismatches = @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' })
        $mismatches.Count | Should -BeGreaterOrEqual 1
    }

    It 'Does not fire AgentMaturityLabelMismatch for experimental agent with (exp) suffix' {
        Set-AgentFrontmatter -Name 'Test(exp)'
        Set-CollectionManifest -Id 'exp-ok' -Maturity 'experimental'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -Be 0
    }

    It 'Fires AgentMaturityLabelMismatch for preview agent missing (pre) suffix' {
        Set-AgentFrontmatter -Name 'Test'
        Set-CollectionManifest -Id 'pre-missing' -Maturity 'preview'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Does not fire AgentMaturityLabelMismatch for preview agent with (pre) suffix' {
        Set-AgentFrontmatter -Name 'Test(pre)'
        Set-CollectionManifest -Id 'pre-ok' -Maturity 'preview'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -Be 0
    }

    It 'Does not fire AgentMaturityLabelMismatch for stable agent without suffix' {
        Set-AgentFrontmatter -Name 'Test'
        Set-CollectionManifest -Id 'stable-ok' -Maturity 'stable'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -Be 0
    }

    It 'Item-level maturity overrides collection-level when validating suffix' {
        # Collection is stable but item override is preview -> requires (pre) suffix
        Set-AgentFrontmatter -Name 'Test(pre)'
        Set-CollectionManifest -Id 'override-ok' -Maturity 'stable' -ItemMaturity 'preview'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -Be 0
    }

    # --- Step 2.2 negative cases ---

    It 'Fires AgentMaturityLabelMismatch for experimental agent with wrong (pre) suffix' {
        Set-AgentFrontmatter -Name 'Test(pre)'
        Set-CollectionManifest -Id 'exp-wrong' -Maturity 'experimental'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch for preview agent with wrong (exp) suffix' {
        Set-AgentFrontmatter -Name 'Test(exp)'
        Set-CollectionManifest -Id 'pre-wrong' -Maturity 'preview'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch for experimental agent with obsolete (Experimental) full word' {
        Set-AgentFrontmatter -Name 'Test(Experimental)'
        Set-CollectionManifest -Id 'exp-fullword' -Maturity 'experimental'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch for preview agent with obsolete (Preview) full word' {
        Set-AgentFrontmatter -Name 'Test(Preview)'
        Set-CollectionManifest -Id 'pre-fullword' -Maturity 'preview'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch for stable agent with stale (exp) suffix' {
        Set-AgentFrontmatter -Name 'Test(exp)'
        Set-CollectionManifest -Id 'stable-stale-exp' -Maturity 'stable'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch for stable agent with stale (pre) suffix' {
        Set-AgentFrontmatter -Name 'Test(pre)'
        Set-CollectionManifest -Id 'stable-stale-pre' -Maturity 'stable'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch for agent name ending with stacked (exp)(pre)' {
        Set-AgentFrontmatter -Name 'Test(exp)(pre)'
        Set-CollectionManifest -Id 'stacked' -Maturity 'experimental'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch when name field is missing on non-stable agent' {
        Set-AgentFrontmatter -OmitName -Name 'unused'
        Set-CollectionManifest -Id 'missing-name' -Maturity 'experimental'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'Invoke-CollectionValidation - MissingExplicitMaturity diagnostic' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'missing-maturity-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'test.agent.md') -Value "---`nname: Test`ndescription: test agent`n---"
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Fires MissingExplicitMaturity when item omits maturity' {
        $manifest = [ordered]@{
            id          = 'test-missing-maturity'
            name        = 'Test'
            description = 'Tests missing item maturity'
            maturity    = 'stable'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'test-missing-maturity.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'MissingExplicitMaturity' }).Count | Should -BeGreaterOrEqual 1
        $result.Success | Should -BeFalse
    }

    It 'Does not fire MissingExplicitMaturity when item declares explicit maturity' {
        $manifest = [ordered]@{
            id          = 'test-has-maturity'
            name        = 'Test'
            description = 'Tests explicit item maturity'
            maturity    = 'stable'
            items       = @(
                [ordered]@{
                    path     = '.github/agents/test/test.agent.md'
                    kind     = 'agent'
                    maturity = 'stable'
                }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'test-has-maturity.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'MissingExplicitMaturity' }).Count | Should -Be 0
    }
}

Describe 'Invoke-CollectionValidation - MissingPrereleaseDescription diagnostic' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'missing-prerelease-desc-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'test.agent.md') -Value '---'
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Does not fire MissingPrereleaseDescription when descriptions.prerelease is populated' {
        $manifest = [ordered]@{
            id           = 'test-has-prerelease'
            name         = 'Test'
            description  = 'Tests prerelease description present'
            maturity     = 'experimental'
            descriptions = [ordered]@{
                stable     = 'Stable description'
                prerelease = 'Experimental: pre-release description'
            }
            items        = @(
                [ordered]@{
                    path     = '.github/agents/test/test.agent.md'
                    kind     = 'agent'
                    maturity = 'experimental'
                }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'test-has-prerelease.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        Set-Content -Path (Join-Path $script:collectionsDir 'test-has-prerelease.collection.md') -Value '# Test'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'MissingPrereleaseDescription' }).Count | Should -Be 0
    }

    It 'Fires MissingPrereleaseDescription as a Warning when descriptions key is absent' {
        $manifest = [ordered]@{
            id          = 'test-missing-descriptions'
            name        = 'Test'
            description = 'Tests missing descriptions block'
            maturity    = 'experimental'
            items       = @(
                [ordered]@{
                    path     = '.github/agents/test/test.agent.md'
                    kind     = 'agent'
                    maturity = 'experimental'
                }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'test-missing-descriptions.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        Set-Content -Path (Join-Path $script:collectionsDir 'test-missing-descriptions.collection.md') -Value '# Test'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $warnings = @($result.Results | Where-Object { $_.ErrorType -eq 'MissingPrereleaseDescription' })
        $warnings.Count | Should -BeGreaterOrEqual 1
        $warnings[0].Severity | Should -Be 'Warning'
    }

    It 'Fires MissingPrereleaseDescription when descriptions.prerelease is whitespace-only' {
        $manifest = [ordered]@{
            id           = 'test-whitespace-prerelease'
            name         = 'Test'
            description  = 'Tests whitespace prerelease description'
            maturity     = 'experimental'
            descriptions = [ordered]@{
                stable     = 'Stable description'
                prerelease = '   '
            }
            items        = @(
                [ordered]@{
                    path     = '.github/agents/test/test.agent.md'
                    kind     = 'agent'
                    maturity = 'experimental'
                }
            )
        }
        Set-Content -Path (Join-Path $script:collectionsDir 'test-whitespace-prerelease.collection.yml') -Value (ConvertTo-Yaml -Data $manifest)
        Set-Content -Path (Join-Path $script:collectionsDir 'test-whitespace-prerelease.collection.md') -Value '# Test'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'MissingPrereleaseDescription' }).Count | Should -BeGreaterOrEqual 1
    }
}
