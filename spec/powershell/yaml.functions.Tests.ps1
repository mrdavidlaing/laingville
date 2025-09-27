# PowerShell tests for yaml.functions.ps1
# Uses Pester BDD syntax similar to ShellSpec

BeforeAll {
    # Import the functions to test
    . "$PSScriptRoot/../../lib/yaml.functions.ps1"

    # Create temporary directory for test files
    $script:tempDir = Join-Path $TestDrive "yaml_tests"
    New-Item -ItemType Directory -Path $script:tempDir -Force
}

Describe "yaml.functions.ps1" {

    Describe "Get-PackagesFromYaml" {

        Context "when YAML file does not exist" {
            It "returns empty hashtable" {
                $result = Get-PackagesFromYaml "/non/existent/file.yaml"

                $result | Should -BeOfType [hashtable]
                $result.winget | Should -Be @()
                $result.pacman | Should -Be @()
                $result.aur | Should -Be @()
            }
        }

        Context "when YAML file contains Windows packages" {
            BeforeEach {
                $script:testYamlFile = Join-Path $script:tempDir "packages.yaml"
            }

            It "extracts winget packages from list format" {
                $yamlContent = @"
windows:
  winget:
    - Git.Git
    - Microsoft.PowerShell
    - Microsoft.VisualStudioCode
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.winget | Should -HaveCount 3
                $result.winget | Should -Contain "Git.Git"
                $result.winget | Should -Contain "Microsoft.PowerShell"
                $result.winget | Should -Contain "Microsoft.VisualStudioCode"
            }

            It "extracts winget packages from inline array format" {
                $yamlContent = @"
windows:
  winget: [Git.Git, Microsoft.PowerShell]
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.winget | Should -HaveCount 2
                $result.winget | Should -Contain "Git.Git"
                $result.winget | Should -Contain "Microsoft.PowerShell"
            }

            It "handles quoted package names" {
                $yamlContent = @"
windows:
  winget:
    - "Git.Git"
    - 'Microsoft.PowerShell'
    - Microsoft.VisualStudioCode
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.winget | Should -HaveCount 3
                $result.winget | Should -Contain "Git.Git"
                $result.winget | Should -Contain "Microsoft.PowerShell"
                $result.winget | Should -Contain "Microsoft.VisualStudioCode"
            }

            It "handles comments in package lists" {
                $yamlContent = @"
# Package configuration for test server
# Windows machine configuration

windows:
  winget:
    # Essential Windows tools
    - Microsoft.PowerShell  # PowerShell 7
    - Git.Git
    - Microsoft.VisualStudioCode  # VS Code editor
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.winget | Should -HaveCount 3
                $result.winget | Should -Contain "Microsoft.PowerShell"
                $result.winget | Should -Contain "Git.Git"
                $result.winget | Should -Contain "Microsoft.VisualStudioCode"
            }

            It "handles inline comments after package names" {
                $yamlContent = @"
windows:
  winget:
    - Git.Git  # Version control
    - Microsoft.PowerShell  # PowerShell 7
    - Microsoft.VisualStudioCode  # Code editor
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.winget | Should -HaveCount 3
                $result.winget | Should -Contain "Git.Git"
                $result.winget | Should -Contain "Microsoft.PowerShell"
                $result.winget | Should -Contain "Microsoft.VisualStudioCode"
            }

            It "handles comment-only lines in package lists" {
                $yamlContent = @"
windows:
  winget:
    # Development tools
    - Git.Git
    # PowerShell
    - Microsoft.PowerShell
    # Editor
    - Microsoft.VisualStudioCode
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.winget | Should -HaveCount 3
                $result.winget | Should -Contain "Git.Git"
                $result.winget | Should -Contain "Microsoft.PowerShell"
                $result.winget | Should -Contain "Microsoft.VisualStudioCode"
            }

            It "handles empty winget section" {
                $yamlContent = @"
windows:
  winget:
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.winget | Should -Be @()
            }

            It "handles missing windows section" {
                $yamlContent = @"
arch:
  pacman:
    - git
    - vim
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.winget | Should -Be @()
            }

            It "extracts scoop packages from list format" {
                $yamlContent = @"
windows:
  scoop:
    - git
    - versions/wezterm-nightly
    - extras/firefox
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.scoop | Should -HaveCount 3
                $result.scoop | Should -Contain "git"
                $result.scoop | Should -Contain "versions/wezterm-nightly"
                $result.scoop | Should -Contain "extras/firefox"
            }

            It "extracts scoop packages from inline array format" {
                $yamlContent = @"
windows:
  scoop: [git, versions/wezterm-nightly]
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.scoop | Should -HaveCount 2
                $result.scoop | Should -Contain "git"
                $result.scoop | Should -Contain "versions/wezterm-nightly"
            }

            It "handles quoted scoop package names with buckets" {
                $yamlContent = @"
windows:
  scoop:
    - "git"
    - 'versions/wezterm-nightly'
    - extras/firefox
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.scoop | Should -HaveCount 3
                $result.scoop | Should -Contain "git"
                $result.scoop | Should -Contain "versions/wezterm-nightly"
                $result.scoop | Should -Contain "extras/firefox"
            }

            It "handles empty scoop section" {
                $yamlContent = @"
windows:
  scoop:
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.scoop | Should -Be @()
            }

            It "handles comments in scoop package lists" {
                $yamlContent = @"
windows:
  scoop:
    # Development tools
    - git  # Version control
    - versions/wezterm-nightly  # Terminal
    - extras/firefox  # Browser
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.scoop | Should -HaveCount 3
                $result.scoop | Should -Contain "git"
                $result.scoop | Should -Contain "versions/wezterm-nightly"
                $result.scoop | Should -Contain "extras/firefox"
            }

            It "extracts psmodule packages from list format" {
                $yamlContent = @"
windows:
  psmodule:
    - PowerShellGet
    - Pester
    - PSReadLine
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.psmodule | Should -HaveCount 3
                $result.psmodule | Should -Contain "PowerShellGet"
                $result.psmodule | Should -Contain "Pester"
                $result.psmodule | Should -Contain "PSReadLine"
            }

            It "handles comments in psmodule package lists" {
                $yamlContent = @"
windows:
  psmodule:
    # Core modules
    - PowerShellGet  # Package manager
    - Pester  # Testing framework
    - PSReadLine  # Enhanced readline
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.psmodule | Should -HaveCount 3
                $result.psmodule | Should -Contain "PowerShellGet"
                $result.psmodule | Should -Contain "Pester"
                $result.psmodule | Should -Contain "PSReadLine"
            }

            It "extracts both winget and scoop packages" {
                $yamlContent = @"
windows:
  winget:
    - Git.Git
    - Microsoft.PowerShell
  scoop:
    - versions/wezterm-nightly
    - extras/firefox
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result.winget | Should -HaveCount 2
                $result.winget | Should -Contain "Git.Git"
                $result.winget | Should -Contain "Microsoft.PowerShell"

                $result.scoop | Should -HaveCount 2
                $result.scoop | Should -Contain "versions/wezterm-nightly"
                $result.scoop | Should -Contain "extras/firefox"
            }
        }

        Context "when YAML file has parsing errors" {
            It "handles malformed YAML gracefully" {
                $script:testYamlFile = Join-Path $script:tempDir "malformed.yaml"
                $yamlContent = "invalid: yaml: content: ["
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-PackagesFromYaml $script:testYamlFile

                $result | Should -BeOfType [hashtable]
                $result.winget | Should -Be @()
            }
        }
    }

    Describe "Get-SymlinksFromYaml" {

        Context "when YAML file does not exist" {
            It "returns empty array" {
                $result = Get-SymlinksFromYaml "/non/existent/file.yaml"

                $result | Should -Be @()
            }
        }

        Context "when YAML file contains Windows symlinks" {
            BeforeEach {
                $script:testYamlFile = Join-Path $script:tempDir "symlinks.yaml"
            }

            It "extracts simple symlinks (source equals target)" {
                $yamlContent = @"
windows:
  - .gitconfig
  - .vimrc
  - Documents/scripts
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-SymlinksFromYaml $script:testYamlFile

                $result | Should -HaveCount 3
                $result[0].source | Should -Be ".gitconfig"
                $result[0].target | Should -Be ".gitconfig"
                $result[1].source | Should -Be ".vimrc"
                $result[1].target | Should -Be ".vimrc"
                $result[2].source | Should -Be "Documents/scripts"
                $result[2].target | Should -Be "Documents/scripts"
            }

            It "extracts complex symlinks with different source and target" {
                $yamlContent = @"
windows:
  - source: .config/git/config
    target: .gitconfig
  - source: .vimrc
    target: _vimrc
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-SymlinksFromYaml $script:testYamlFile

                $result | Should -HaveCount 2
                $result[0].source | Should -Be ".config/git/config"
                $result[0].target | Should -Be ".gitconfig"
                $result[1].source | Should -Be ".vimrc"
                $result[1].target | Should -Be "_vimrc"
            }

            It "handles mixed simple and complex symlinks" {
                $yamlContent = @"
windows:
  - .gitconfig
  - source: .config/powershell/profile.ps1
    target: Documents/PowerShell/profile.ps1
  - .vimrc
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-SymlinksFromYaml $script:testYamlFile

                $result | Should -HaveCount 3
                $result[0].source | Should -Be ".gitconfig"
                $result[0].target | Should -Be ".gitconfig"
                $result[1].source | Should -Be ".config/powershell/profile.ps1"
                $result[1].target | Should -Be "Documents/PowerShell/profile.ps1"
                $result[2].source | Should -Be ".vimrc"
                $result[2].target | Should -Be ".vimrc"
            }

            It "handles empty windows section" {
                $yamlContent = @"
windows:
arch:
  - .bashrc
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-SymlinksFromYaml $script:testYamlFile

                $result | Should -Be @()
            }

            It "handles missing windows section" {
                $yamlContent = @"
arch:
  - .bashrc
  - .vimrc
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-SymlinksFromYaml $script:testYamlFile

                $result | Should -Be @()
            }
        }

        Context "when YAML file has different platforms" {
            It "extracts symlinks for specified platform" {
                $script:testYamlFile = Join-Path $script:tempDir "multi_platform.yaml"
                $yamlContent = @"
arch:
  - .bashrc
  - .vimrc
windows:
  - .gitconfig
  - Documents/scripts
macos:
  - .zshrc
"@
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $archResult = Get-SymlinksFromYaml $script:testYamlFile "arch"
                $windowsResult = Get-SymlinksFromYaml $script:testYamlFile "windows"
                $macosResult = Get-SymlinksFromYaml $script:testYamlFile "macos"

                $archResult | Should -HaveCount 2
                $archResult[0].source | Should -Be ".bashrc"

                $windowsResult | Should -HaveCount 2
                $windowsResult[0].source | Should -Be ".gitconfig"

                $macosResult | Should -HaveCount 1
                $macosResult[0].source | Should -Be ".zshrc"
            }
        }

        Context "when YAML file has parsing errors" {
            It "handles malformed YAML gracefully" {
                $script:testYamlFile = Join-Path $script:tempDir "malformed_symlinks.yaml"
                $yamlContent = "invalid: yaml: content: ["
                Set-Content -Path $script:testYamlFile -Value $yamlContent

                $result = Get-SymlinksFromYaml $script:testYamlFile

                $result | Should -Be @()
            }
        }
    }
}
