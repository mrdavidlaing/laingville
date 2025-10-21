#!/usr/bin/env pwsh

# Import required modules
BeforeAll {
    $ProjectRoot = Resolve-Path "$PSScriptRoot/../.."
    $LibDir = Join-Path $ProjectRoot "lib"

    # Source the function files
    . "$LibDir/logging.functions.ps1"
    . "$LibDir/claudecode.functions.ps1"
}

Describe "Claude Code Plugin Management" {
    Context "Get-ClaudeCodePluginsFromYaml" {
        It "extracts plugins from valid packages.yaml" {
            $yamlContent = @"
claudecode:
  plugins:
    - superpowers@obra/superpowers-marketplace
    - another-plugin@user/repo
"@

            $plugins = Get-ClaudeCodePluginsFromYaml $yamlContent
            $plugins | Should -HaveCount 2
            $plugins[0] | Should -Be "superpowers@obra/superpowers-marketplace"
            $plugins[1] | Should -Be "another-plugin@user/repo"
        }

        It "returns empty array when claudecode section missing" {
            $yamlContent = @"
arch:
  pacman:
    - vim
"@

            $plugins = Get-ClaudeCodePluginsFromYaml $yamlContent
            $plugins | Should -HaveCount 0
        }

        It "returns empty array when plugins subsection missing" {
            $yamlContent = @"
claudecode:
  other:
    - something
"@

            $plugins = Get-ClaudeCodePluginsFromYaml $yamlContent
            $plugins | Should -HaveCount 0
        }

        It "handles empty input" {
            $plugins = Get-ClaudeCodePluginsFromYaml ""
            $plugins | Should -HaveCount 0
        }

        It "exits claudecode section when hitting another top-level key" {
            $yamlContent = @"
claudecode:
  plugins:
    - plugin1@owner/repo
windows:
  winget:
    - not-a-plugin
"@

            $plugins = Get-ClaudeCodePluginsFromYaml $yamlContent
            $plugins | Should -HaveCount 1
            $plugins[0] | Should -Be "plugin1@owner/repo"
        }
    }

    Context "Get-MarketplaceFromPlugin" {
        It "extracts marketplace from plugin@marketplace format" {
            $marketplace = Get-MarketplaceFromPlugin "superpowers@obra/superpowers-marketplace"
            $marketplace | Should -Be "obra/superpowers-marketplace"
        }

        It "returns null for invalid format without @" {
            $marketplace = Get-MarketplaceFromPlugin "invalid-plugin"
            $marketplace | Should -BeNullOrEmpty
        }

        It "handles plugin names with hyphens" {
            $marketplace = Get-MarketplaceFromPlugin "my-plugin@owner/my-marketplace"
            $marketplace | Should -Be "owner/my-marketplace"
        }

        It "handles empty input" {
            $marketplace = Get-MarketplaceFromPlugin ""
            $marketplace | Should -BeNullOrEmpty
        }
    }

    Context "Add-ClaudeCodeMarketplace" {
        BeforeEach {
            # Mock claude.exe command
            Mock -CommandName claude.exe -MockWith { return "" }
        }

        It "calls claude.exe plugin marketplace add with valid marketplace" {
            $result = Add-ClaudeCodeMarketplace -Marketplace "obra/superpowers-marketplace" -DryRun $false
            $result | Should -Be $true
            Should -Invoke -CommandName claude.exe -Times 1 -ParameterFilter {
                $args -join " " -eq "plugin marketplace add obra/superpowers-marketplace"
            }
        }

        It "rejects unsafe marketplace names" {
            $result = Add-ClaudeCodeMarketplace -Marketplace "obra/super; rm -rf" -DryRun $false
            $result | Should -Be $false
            Should -Invoke -CommandName claude.exe -Times 0
        }

        It "shows dry-run message without calling claude.exe" {
            $result = Add-ClaudeCodeMarketplace -Marketplace "obra/superpowers-marketplace" -DryRun $true
            $result | Should -Be $true
            Should -Invoke -CommandName claude.exe -Times 0
        }

        It "returns false when marketplace is empty" {
            $result = Add-ClaudeCodeMarketplace -Marketplace "" -DryRun $false
            $result | Should -Be $false
            Should -Invoke -CommandName claude.exe -Times 0
        }

        It "handles claude.exe failures gracefully" {
            Mock -CommandName claude.exe -MockWith { throw "Command failed" }
            $result = Add-ClaudeCodeMarketplace -Marketplace "obra/superpowers-marketplace" -DryRun $false
            $result | Should -Be $true  # Returns true because failure is non-fatal
        }
    }

    Context "Install-ClaudeCodePlugin" {
        BeforeEach {
            # Mock claude.exe command
            Mock -CommandName claude.exe -MockWith { return "" }
        }

        It "calls claude.exe plugin install with valid plugin" {
            $result = Install-ClaudeCodePlugin -Plugin "superpowers@obra/superpowers-marketplace" -DryRun $false
            $result | Should -Be $true
            Should -Invoke -CommandName claude.exe -Times 1 -ParameterFilter {
                $args -join " " -eq "plugin install superpowers@obra/superpowers-marketplace"
            }
        }

        It "rejects invalid plugin format without @" {
            $result = Install-ClaudeCodePlugin -Plugin "invalid-no-marketplace" -DryRun $false
            $result | Should -Be $false
            Should -Invoke -CommandName claude.exe -Times 0
        }

        It "shows dry-run message without calling claude.exe" {
            $result = Install-ClaudeCodePlugin -Plugin "superpowers@obra/superpowers-marketplace" -DryRun $true
            $result | Should -Be $true
            Should -Invoke -CommandName claude.exe -Times 0
        }

        It "returns false when plugin is empty" {
            $result = Install-ClaudeCodePlugin -Plugin "" -DryRun $false
            $result | Should -Be $false
            Should -Invoke -CommandName claude.exe -Times 0
        }

        It "rejects unsafe plugin names" {
            $result = Install-ClaudeCodePlugin -Plugin "bad@owner/repo; rm -rf" -DryRun $false
            $result | Should -Be $false
            Should -Invoke -CommandName claude.exe -Times 0
        }

        It "handles claude.exe failures" {
            Mock -CommandName claude.exe -MockWith { throw "Command failed" }
            $result = Install-ClaudeCodePlugin -Plugin "superpowers@obra/superpowers-marketplace" -DryRun $false
            $result | Should -Be $false  # Returns false on plugin install failure
        }
    }

    Context "Invoke-ClaudeCodePluginSetup" {
        BeforeEach {
            # Mock claude.exe command
            Mock -CommandName claude.exe -MockWith { return "" }

            # Create temporary packages.yaml
            $tempDir = Join-Path $TestDrive "dotfiles"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            $env:DOTFILES_DIR = $tempDir
        }

        It "processes all plugins and deduplicates marketplaces" {
            $yamlContent = @"
claudecode:
  plugins:
    - plugin1@owner1/marketplace1
    - plugin2@owner1/marketplace1
    - plugin3@owner2/marketplace2
"@
            Set-Content -Path (Join-Path $env:DOTFILES_DIR "packages.yaml") -Value $yamlContent

            $result = Invoke-ClaudeCodePluginSetup -DryRun $false
            $result | Should -Be $true

            # Should add each marketplace only once
            Should -Invoke -CommandName claude.exe -Times 2 -ParameterFilter {
                $args[0] -eq "plugin" -and $args[1] -eq "marketplace" -and $args[2] -eq "add"
            }

            # Should install all plugins
            Should -Invoke -CommandName claude.exe -Times 3 -ParameterFilter {
                $args[0] -eq "plugin" -and $args[1] -eq "install"
            }
        }

        It "handles missing packages.yaml gracefully" {
            Remove-Item (Join-Path $env:DOTFILES_DIR "packages.yaml") -ErrorAction SilentlyContinue
            $result = Invoke-ClaudeCodePluginSetup -DryRun $false
            $result | Should -Be $true
            Should -Invoke -CommandName claude.exe -Times 0
        }

        It "handles empty claudecode section gracefully" {
            $yamlContent = @"
arch:
  pacman:
    - vim
"@
            Set-Content -Path (Join-Path $env:DOTFILES_DIR "packages.yaml") -Value $yamlContent

            $result = Invoke-ClaudeCodePluginSetup -DryRun $false
            $result | Should -Be $true
            Should -Invoke -CommandName claude.exe -Times 0
        }

        It "continues with remaining plugins on failure" {
            $yamlContent = @"
claudecode:
  plugins:
    - plugin1@owner1/marketplace1
    - invalid-format
    - plugin2@owner2/marketplace2
"@
            Set-Content -Path (Join-Path $env:DOTFILES_DIR "packages.yaml") -Value $yamlContent

            $result = Invoke-ClaudeCodePluginSetup -DryRun $false
            $result | Should -Be $true

            # Should still process valid plugins
            Should -Invoke -CommandName claude.exe -Times 2 -ParameterFilter {
                $args[0] -eq "plugin" -and $args[1] -eq "install"
            }
        }

        It "works in dry-run mode" {
            $yamlContent = @"
claudecode:
  plugins:
    - plugin1@owner1/marketplace1
"@
            Set-Content -Path (Join-Path $env:DOTFILES_DIR "packages.yaml") -Value $yamlContent

            $result = Invoke-ClaudeCodePluginSetup -DryRun $true
            $result | Should -Be $true
            Should -Invoke -CommandName claude.exe -Times 0
        }
    }
}
