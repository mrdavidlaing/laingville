# PowerShell tests for shared.functions.ps1
# Uses Pester BDD syntax similar to ShellSpec

BeforeAll {
    # Import the functions to test
    . "$PSScriptRoot/../../lib/shared.functions.ps1"
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
                # Mock winget command to avoid actual installations
                Mock winget { 
                    $global:LASTEXITCODE = 0
                    return "Successfully installed package"
                } -ModuleName $null
            }
            
            It "installs each package successfully" {
                $packages = @("Git.Git", "Microsoft.PowerShell")
                
                $result = Install-WingetPackage $packages
                
                Should -Invoke winget -Times 2
                $result | Should -Be $true
            }
            
            It "handles single package installation" {
                $result = Install-WingetPackage @("Git.Git")
                
                Should -Invoke winget -Times 1
                $result | Should -Be $true
            }
            
            It "skips empty package strings" {
                $packages = @("Git.Git", "", "Microsoft.PowerShell")
                
                $result = Install-WingetPackage $packages
                
                Should -Invoke winget -Times 2
                $result | Should -Be $true
            }
        }
        
        Context "when winget returns different exit codes" {
            It "handles package already installed" {
                Mock winget { 
                    $global:LASTEXITCODE = -1978335189
                    return "Package already installed"
                }
                
                $result = Install-WingetPackage @("Git.Git")
                
                $result | Should -Be $true
            }
            
            It "handles package not found" {
                Mock winget { 
                    $global:LASTEXITCODE = -1978335212
                    return "Package not found"
                }
                
                $result = Install-WingetPackage @("NonExistent.Package")
                
                $result | Should -Be $true
            }
            
            It "handles other error codes" {
                Mock winget { 
                    $global:LASTEXITCODE = 1
                    return "Some error occurred"
                }
                
                $result = Install-WingetPackage @("Problematic.Package")
                
                $result | Should -Be $true
            }
        }
        
        Context "when winget throws exceptions" {
            It "handles exceptions gracefully" {
                Mock winget { throw "Command not found" }
                
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
}