BeforeAll {
    . "$PSScriptRoot/../../lib/logging.functions.ps1"
    . "$PSScriptRoot/../../lib/security.functions.ps1"
    . "$PSScriptRoot/../../lib/yaml.functions.ps1"
    . "$PSScriptRoot/../../lib/shared.functions.ps1"
}

Describe "Windows Package Cleanup Functions" {
    Context "Remove-WingetPackage" {
        BeforeEach {
            Mock Invoke-Winget { $global:LASTEXITCODE = 0 }
        }

        It "removes packages using winget uninstall" {
            $packages = @("Git.Git", "Alacritty.Alacritty")
            
            Remove-WingetPackage -Packages $packages
            
            Should -Invoke Invoke-Winget -Times 2
            Should -Invoke Invoke-Winget -ParameterFilter { 
                $Arguments -contains "uninstall" -and $Arguments -contains "Git.Git"
            }
            Should -Invoke Invoke-Winget -ParameterFilter { 
                $Arguments -contains "uninstall" -and $Arguments -contains "Alacritty.Alacritty"
            }
        }

        It "handles empty package list" {
            $result = Remove-WingetPackage -Packages @()
            
            $result | Should -Be $true
            Should -Invoke Invoke-Winget -Times 0
        }

        It "handles package not found gracefully" {
            Mock Invoke-Winget { $global:LASTEXITCODE = -1978335212 }

            $result = Remove-WingetPackage -Packages @("NonExistent.Package")

            $result | Should -Be $true
        }

        It "reports uninstaller failures with helpful message" {
            Mock Invoke-Winget { $global:LASTEXITCODE = -1978335184 }

            $result = Remove-WingetPackage -Packages @("Alacritty.Alacritty")

            # Still returns true (doesn't fail the whole operation)
            $result | Should -Be $true
        }
    }

    Context "Remove-ScoopPackage" {
        BeforeEach {
            Mock Get-Command { return $true } -ParameterFilter { $Name -eq "scoop" }
            Mock Invoke-Scoop { $global:LASTEXITCODE = 0 }
        }

        It "removes packages using scoop uninstall" {
            $packages = @("git", "alacritty")
            
            Remove-ScoopPackage -Packages $packages
            
            Should -Invoke Invoke-Scoop -Times 2
            Should -Invoke Invoke-Scoop -ParameterFilter { 
                $Arguments -contains "uninstall" -and $Arguments -contains "git"
            }
        }

        It "handles bucket/package format" {
            $packages = @("versions/wezterm-nightly")
            
            Remove-ScoopPackage -Packages $packages
            
            Should -Invoke Invoke-Scoop -ParameterFilter { 
                $Arguments -contains "uninstall" -and $Arguments -contains "wezterm-nightly"
            }
        }

        It "skips when scoop not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq "scoop" }
            
            $result = Remove-ScoopPackage -Packages @("git")
            
            $result | Should -Be $true
            Should -Invoke Invoke-Scoop -Times 0
        }
    }

    Context "Remove-PowerShellModule" {
        It "removes PowerShell modules" {
            Mock Get-Module {
                return @{ Name = $Name; Version = "1.0.0" }
            }

            # Create a simple mock function since Uninstall-Module may not be available
            function script:Uninstall-Module {
                param($Name, [switch]$Force, $ErrorAction)
            }

            $modules = @("Pester", "PSScriptAnalyzer")
            $result = Remove-PowerShellModule -Modules $modules

            # Should complete successfully
            $result | Should -Be $true
        }

        It "handles module not installed" {
            Mock Get-Module { return $null }

            $result = Remove-PowerShellModule -Modules @("NonExistent")

            $result | Should -Be $true
        }

        It "handles errors during uninstall gracefully" {
            Mock Get-Module {
                return @{ Name = $Name; Version = "1.0.0" }
            }

            # Create a mock that throws an error
            function script:Uninstall-Module {
                param($Name, [switch]$Force, $ErrorAction)
                throw "Simulated uninstall error"
            }

            $result = Remove-PowerShellModule -Modules @("FailingModule")

            # Should still return true (logged warning, but doesn't fail)
            $result | Should -Be $true
        }
    }
}

Describe "YAML Cleanup Parsing" {
    Context "Get-PackagesFromYaml with cleanup sections" {
        BeforeAll {
            $testYaml = @"
windows:
  winget:
    - Git.Git
    - Microsoft.PowerShell
  winget_cleanup:
    - Alacritty.Alacritty
  scoop:
    - versions/wezterm-nightly
  scoop_cleanup:
    - alacritty
  psmodule:
    - Pester
  psmodule_cleanup:
    - OldModule
"@
            $testFile = Join-Path $TestDrive "test-packages.yaml"
            Set-Content -Path $testFile -Value $testYaml
        }

        It "extracts winget_cleanup packages" {
            $packages = Get-PackagesFromYaml -YamlFile $testFile
            
            $packages.winget_cleanup | Should -Contain "Alacritty.Alacritty"
            $packages.winget_cleanup.Count | Should -Be 1
        }

        It "extracts scoop_cleanup packages" {
            $packages = Get-PackagesFromYaml -YamlFile $testFile
            
            $packages.scoop_cleanup | Should -Contain "alacritty"
            $packages.scoop_cleanup.Count | Should -Be 1
        }

        It "extracts psmodule_cleanup packages" {
            $packages = Get-PackagesFromYaml -YamlFile $testFile
            
            $packages.psmodule_cleanup | Should -Contain "OldModule"
            $packages.psmodule_cleanup.Count | Should -Be 1
        }

        It "still extracts regular packages" {
            $packages = Get-PackagesFromYaml -YamlFile $testFile
            
            $packages.winget | Should -Contain "Git.Git"
            $packages.scoop | Should -Contain "versions/wezterm-nightly"
            $packages.psmodule | Should -Contain "Pester"
        }
    }
}
