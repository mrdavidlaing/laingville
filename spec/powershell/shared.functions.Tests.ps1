# PowerShell tests for shared.functions.ps1
# Uses Pester BDD syntax similar to ShellSpec

# Suppress PSScriptAnalyzer warnings for test mock functions - these are test stubs not production code
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
param()

BeforeAll {
    # Import the functions to test
    . "$PSScriptRoot/../../lib/shared.functions.ps1"
    
    # Note: We now mock Invoke-Winget and Invoke-Scoop wrapper functions instead of external commands
    
    # Create stubs for PowerShell commands used in Scoop installation (test mocks only)
    if (-not (Get-Command Set-ExecutionPolicy -ErrorAction SilentlyContinue)) {
        function Set-ExecutionPolicy { }
    }
    if (-not (Get-Command Invoke-RestMethod -ErrorAction SilentlyContinue)) {
        function Invoke-RestMethod { }
    }
    if (-not (Get-Command Invoke-Expression -ErrorAction SilentlyContinue)) {
        function Invoke-Expression { }
    }
}

Describe "shared.functions.ps1" {
    
    Describe "Install-WingetPackage" {
        
        Context "when no packages are provided" {
            It "returns true for empty array" {
                $result = Install-WingetPackage @()
                $result | Should -Be $true
            }
            
            It "returns true for null input" {
                $result = Install-WingetPackage $null
                $result | Should -Be $true
            }
        }
        
        Context "when packages are provided" {
            BeforeEach {
                # Mock Invoke-Winget wrapper function to avoid actual installations
                Mock Invoke-Winget { 
                    $global:LASTEXITCODE = 0
                    return "Successfully installed package"
                }
            }
            
            It "installs each package successfully" {
                $packages = @("Git.Git", "Microsoft.PowerShell")
                
                $result = Install-WingetPackage $packages
                
                Should -Invoke Invoke-Winget -Times 2
                $result | Should -Be $true
            }
            
            It "handles single package installation" {
                $result = Install-WingetPackage @("Git.Git")
                
                Should -Invoke Invoke-Winget -Times 1
                $result | Should -Be $true
            }
            
            It "skips empty package strings" {
                $packages = @("Git.Git", "", "Microsoft.PowerShell")
                
                $result = Install-WingetPackage $packages
                
                Should -Invoke Invoke-Winget -Times 2
                $result | Should -Be $true
            }
        }
        
        Context "when winget returns different exit codes" {
            It "handles package already installed" {
                Mock Invoke-Winget { 
                    $global:LASTEXITCODE = -1978335189
                    return "Package already installed"
                }
                
                $result = Install-WingetPackage @("Git.Git")
                
                $result | Should -Be $true
            }
            
            It "handles package not found" {
                Mock Invoke-Winget { 
                    $global:LASTEXITCODE = -1978335212
                    return "Package not found"
                }
                
                $result = Install-WingetPackage @("NonExistent.Package")
                
                $result | Should -Be $true
            }
            
            It "handles other error codes" {
                Mock Invoke-Winget { 
                    $global:LASTEXITCODE = 1
                    return "Some error occurred"
                }
                
                $result = Install-WingetPackage @("Problematic.Package")
                
                $result | Should -Be $true
            }
        }
        
        Context "when winget throws exceptions" {
            It "handles exceptions gracefully" {
                Mock Invoke-Winget { throw "Command not found" }
                
                $result = Install-WingetPackage @("Any.Package")
                
                $result | Should -Be $true
            }
        }
    }
    
    Describe "Get-CurrentUser" {
        
        Context "when USERNAME environment variable is set" {
            BeforeEach {
                # Store original value to restore later
                $script:originalUsername = $env:USERNAME
            }
            
            AfterEach {
                # Restore original value
                $env:USERNAME = $script:originalUsername
            }
            
            It "maps 'timmy' to 'timmmmmmer'" {
                $env:USERNAME = "timmy"
                
                $result = Get-CurrentUser
                
                $result | Should -Be "timmmmmmer"
            }
            
            It "maps 'TIMMY' to 'timmmmmmer' (case insensitive)" {
                $env:USERNAME = "TIMMY"
                
                $result = Get-CurrentUser
                
                $result | Should -Be "timmmmmmer"
            }
            
            It "maps 'david' to 'mrdavidlaing'" {
                $env:USERNAME = "david"
                
                $result = Get-CurrentUser
                
                $result | Should -Be "mrdavidlaing"
            }
            
            It "maps 'davidlaing' to 'mrdavidlaing'" {
                $env:USERNAME = "davidlaing"
                
                $result = Get-CurrentUser
                
                $result | Should -Be "mrdavidlaing"
            }
            
            It "maps unknown users to 'shared'" {
                $env:USERNAME = "unknownuser"
                
                $result = Get-CurrentUser
                
                $result | Should -Be "shared"
            }
        }
    }
    
    Describe "Expand-WindowsPath" {
        
        Context "when path contains environment variables" {
            It "expands APPDATA variable" {
                $testPath = '$APPDATA\myapp\config.json'
                $expectedPath = "$env:APPDATA\myapp\config.json"
                
                $result = Expand-WindowsPath $testPath
                
                $result | Should -Be $expectedPath
            }
            
            It "expands LOCALAPPDATA variable" {
                $testPath = '$LOCALAPPDATA\myapp\data'
                $expectedPath = "$env:LOCALAPPDATA\myapp\data"
                
                $result = Expand-WindowsPath $testPath
                
                $result | Should -Be $expectedPath
            }
            
            It "expands USERPROFILE variable" {
                $testPath = '$USERPROFILE\Documents\file.txt'
                $expectedPath = "$env:USERPROFILE\Documents\file.txt"
                
                $result = Expand-WindowsPath $testPath
                
                $result | Should -Be $expectedPath
            }
        }
        
        Context "when path is relative without environment variables" {
            It "uses USERPROFILE as base for relative paths" {
                $testPath = 'Documents\file.txt'
                $expectedPath = "$env:USERPROFILE\Documents\file.txt"
                
                $result = Expand-WindowsPath $testPath
                
                $result | Should -Be $expectedPath
            }
        }
        
        Context "when path is absolute" {
            It "returns absolute paths unchanged" {
                $testPath = 'C:\Program Files\App\config.json'
                
                $result = Expand-WindowsPath $testPath
                
                $result | Should -Be $testPath
            }
        }
    }
    
    Describe "Install-ScoopPackage" {
        
        BeforeEach {
            # Mock Invoke-Scoop wrapper function to avoid actual installations
            Mock Invoke-Scoop { 
                $global:LASTEXITCODE = 0
                if ($Arguments[0] -eq "list" -and $Arguments.Count -eq 1) {
                    # bucket list (no package name)
                    return $null  # Default: no packages installed
                } elseif ($Arguments[0] -eq "list" -and $Arguments.Count -eq 2) {
                    # package list (with package name)
                    return $null  # Default: package not installed
                } elseif ($Arguments[0] -eq "bucket" -and $Arguments[1] -eq "list") {
                    # bucket list command - return empty array (no buckets)
                    return @()
                } elseif ($Arguments[0] -eq "bucket" -and $Arguments[1] -eq "add") {
                    return "Successfully added bucket"
                } elseif ($Arguments[0] -eq "install") {
                    return "Successfully installed package"
                } elseif ($Arguments[0] -eq "update") {
                    return "Successfully updated package"
                }
                return "Default scoop response"
            }
            
            # Mock Get-Command to simulate scoop being available
            Mock Get-Command { return $true } -ParameterFilter { $Name -eq "scoop" }
        }
        
        Context "when no packages are provided" {
            It "returns true for empty array" {
                $result = Install-ScoopPackage @()
                $result | Should -Be $true
            }
            
            It "returns true for null input" {
                $result = Install-ScoopPackage $null
                $result | Should -Be $true
            }
        }
        
        Context "when scoop is not installed" {
            It "automatically installs scoop successfully" {
                # Mock scoop not being found initially, then found after installation
                $script:scoopCallCount = 0
                Mock Get-Command { 
                    $script:scoopCallCount++
                    if ($script:scoopCallCount -eq 1) { return $false }  # First call: not found
                    else { return $true }  # Second call: found after installation
                } -ParameterFilter { $Name -eq "scoop" }
                
                Mock Set-ExecutionPolicy { } 
                Mock Invoke-RestMethod { return "# Mock Scoop installation script" }
                
                $result = Install-ScoopPackage @("git")
                
                Should -Invoke Set-ExecutionPolicy -Times 1
                Should -Invoke Invoke-RestMethod -Times 1
                $result | Should -Be $true
            }
            
            It "handles scoop installation failure gracefully" {
                Mock Get-Command { return $false } -ParameterFilter { $Name -eq "scoop" }
                Mock Set-ExecutionPolicy { throw "Access denied" }
                
                $result = Install-ScoopPackage @("git")
                
                $result | Should -Be $false
            }
            
            It "handles case where scoop installs but command still not found" {
                Mock Get-Command { return $false } -ParameterFilter { $Name -eq "scoop" }
                Mock Set-ExecutionPolicy { } 
                Mock Invoke-RestMethod { return "# Mock Scoop installation script" }
                
                $result = Install-ScoopPackage @("git")
                
                $result | Should -Be $false
            }
        }
        
        Context "when packages are provided" {
            It "installs each package successfully" {
                $packages = @("git", "nodejs")
                
                $result = Install-ScoopPackage $packages
                
                # Should call Invoke-Scoop list for each package, then install for each
                Should -Invoke Invoke-Scoop -Times 4  # 2 list calls + 2 install calls
                $result | Should -Be $true
            }
            
            It "handles single package installation" {
                $result = Install-ScoopPackage @("git")
                
                # Should call Invoke-Scoop list once, then install once
                Should -Invoke Invoke-Scoop -Times 2  # 1 list + 1 install
                $result | Should -Be $true
            }
            
            It "skips empty package strings" {
                $packages = @("git", "", "nodejs")
                
                $result = Install-ScoopPackage $packages
                
                # Should call Invoke-Scoop list for non-empty packages, then install
                Should -Invoke Invoke-Scoop -Times 4  # 2 list calls + 2 install calls
                $result | Should -Be $true
            }
        }
        
        Context "when packages have bucket specifications" {
            It "adds required buckets before installing packages" {
                $packages = @("versions/wezterm-nightly", "extras/firefox", "git")
                
                $result = Install-ScoopPackage $packages
                
                # Should list buckets, add buckets, call list for each package, then install
                Should -Invoke Invoke-Scoop -Times 9  # 1 bucket list + 2 bucket adds + 3 package list calls + 3 install calls
                $result | Should -Be $true
            }
            
            It "handles duplicate buckets correctly" {
                $packages = @("versions/wezterm-nightly", "versions/some-other-package")
                
                $result = Install-ScoopPackage $packages
                
                # Should list buckets, add versions bucket once, call list twice, then install twice
                Should -Invoke Invoke-Scoop -Times 6  # 1 bucket list + 1 bucket add + 2 package list calls + 2 install calls
                $result | Should -Be $true
            }
            
            It "skips adding buckets that already exist" {
                # Mock bucket list to return existing buckets
                Mock Invoke-Scoop { 
                    $global:LASTEXITCODE = 0
                    return @(
                        @{Name="versions"; Source="https://github.com/ScoopInstaller/Versions"},
                        @{Name="extras"; Source="https://github.com/ScoopInstaller/Extras"}
                    )
                } -ParameterFilter { $Arguments[0] -eq "bucket" -and $Arguments[1] -eq "list" }
                
                $result = Install-ScoopPackage @("versions/wezterm-nightly", "extras/firefox")
                
                # Should list buckets, skip adding (since they exist), check packages, then install
                Should -Invoke Invoke-Scoop -ParameterFilter { $Arguments[0] -eq "bucket" -and $Arguments[1] -eq "list" } -Times 1
                Should -Invoke Invoke-Scoop -ParameterFilter { $Arguments[0] -eq "bucket" -and $Arguments[1] -eq "add" } -Times 0
                Should -Invoke Invoke-Scoop -ParameterFilter { $Arguments[0] -eq "list" -and $Arguments.Count -eq 2 } -Times 2
                $result | Should -Be $true
            }
        }
        
        Context "when scoop returns different responses" {
            It "updates package when already installed" {
                # Mock Invoke-Scoop list to return that git is installed
                Mock Invoke-Scoop { 
                    $global:LASTEXITCODE = 0
                    return @{Name="git"; Version="2.45.0"}
                } -ParameterFilter { $Arguments[0] -eq "list" -and $Arguments[1] -eq "git" }
                
                # Mock Invoke-Scoop update
                Mock Invoke-Scoop { 
                    $global:LASTEXITCODE = 0
                    return "git updated successfully"
                } -ParameterFilter { $Arguments[0] -eq "update" }
                
                $result = Install-ScoopPackage @("git")
                
                Should -Invoke Invoke-Scoop -ParameterFilter { $Arguments[0] -eq "list" } -Times 1
                Should -Invoke Invoke-Scoop -ParameterFilter { $Arguments[0] -eq "update" } -Times 1
                Should -Invoke Invoke-Scoop -ParameterFilter { $Arguments[0] -eq "install" } -Times 0
                $result | Should -Be $true
            }
            
            It "updates bucket package when already installed" {
                # Mock Invoke-Scoop list to return that wezterm-nightly is installed
                Mock Invoke-Scoop { 
                    $global:LASTEXITCODE = 0
                    return @{Name="wezterm-nightly"; Version="nightly-20250815"}
                } -ParameterFilter { $Arguments[0] -eq "list" -and $Arguments[1] -eq "wezterm-nightly" }
                
                # Mock Invoke-Scoop update
                Mock Invoke-Scoop { 
                    $global:LASTEXITCODE = 0
                    return "wezterm-nightly updated successfully"
                } -ParameterFilter { $Arguments[0] -eq "update" }
                
                $result = Install-ScoopPackage @("versions/wezterm-nightly")
                
                Should -Invoke Invoke-Scoop -ParameterFilter { $Arguments[0] -eq "bucket" } -Times 2  # bucket list + bucket add
                Should -Invoke Invoke-Scoop -ParameterFilter { $Arguments[0] -eq "list" } -Times 1     # check if installed
                Should -Invoke Invoke-Scoop -ParameterFilter { $Arguments[0] -eq "update" } -Times 1   # update existing
                Should -Invoke Invoke-Scoop -ParameterFilter { $Arguments[0] -eq "install" } -Times 0  # should not install
                $result | Should -Be $true
            }
            
            It "handles package not found" {
                Mock Invoke-Scoop { 
                    $global:LASTEXITCODE = 1
                    return "Could not find package 'nonexistent'"
                } -ParameterFilter { $Arguments[0] -eq "install" }
                
                $result = Install-ScoopPackage @("nonexistent")
                
                $result | Should -Be $true
            }
            
            It "handles bucket already exists" {
                Mock Invoke-Scoop { 
                    if ($Arguments[0] -eq "bucket" -and $Arguments[1] -eq "add") {
                        $global:LASTEXITCODE = 0
                        return "The versions bucket already exists"
                    } else {
                        $global:LASTEXITCODE = 0
                        return "Successfully installed"
                    }
                }
                
                $result = Install-ScoopPackage @("versions/wezterm-nightly")
                
                $result | Should -Be $true
            }
        }
        
        Context "when scoop throws exceptions" {
            It "handles exceptions gracefully" {
                Mock Invoke-Scoop { throw "Command failed" }
                
                $result = Install-ScoopPackage @("git")
                
                $result | Should -Be $true
            }
        }
    }
}