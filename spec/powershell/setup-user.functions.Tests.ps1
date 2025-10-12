# PowerShell tests for setup-user.functions.ps1
# Uses Pester BDD syntax similar to ShellSpec

BeforeAll {
    # Import the functions to test
    . "$PSScriptRoot/../../lib/setup-user.functions.ps1"

    # Create temporary directory for test files
    $script:tempDir = Join-Path $TestDrive "setup_user_tests"
    New-Item -ItemType Directory -Path $script:tempDir -Force
}

Describe "setup-user.functions.ps1" {

    Describe "Get-PlatformConfigPath" {

        Context "when handling Alacritty configuration paths" {
            It "maps .config/alacritty files to APPDATA" {
                $result = Get-PlatformConfigPath ".config/alacritty/" "alacritty.toml"

                $expected = Join-Path $env:APPDATA "alacritty\alacritty.toml"
                $result | Should -Be $expected
            }

            It "handles subdirectories within alacritty config" {
                $result = Get-PlatformConfigPath ".config/alacritty/themes/" "nord.toml"

                $expected = Join-Path $env:APPDATA "alacritty\themes\nord.toml"
                $result | Should -Be $expected
            }

            It "creates the alacritty directory in APPDATA" {
                Get-PlatformConfigPath ".config/alacritty/" "test.toml" | Out-Null
                $alacrittyDir = Join-Path $env:APPDATA "alacritty"

                Test-Path $alacrittyDir | Should -Be $true
            }

            It "creates subdirectories when needed" {
                Get-PlatformConfigPath ".config/alacritty/themes/" "test.toml" | Out-Null
                $themesDir = Join-Path $env:APPDATA "alacritty\themes"

                Test-Path $themesDir | Should -Be $true
            }
        }

        Context "when handling default configuration paths" {
            It "maps standard paths to USERPROFILE" {
                $result = Get-PlatformConfigPath ".config/git/" "config"

                $expected = Join-Path $env:USERPROFILE ".config\git\config"
                $result | Should -Be $expected
            }

            It "handles root-level dotfiles" {
                $result = Get-PlatformConfigPath "" ".gitconfig"

                $expected = Join-Path $env:USERPROFILE ".gitconfig"
                $result | Should -Be $expected
            }

            It "handles Documents folder paths" {
                $result = Get-PlatformConfigPath "Documents/" "script.ps1"

                $expected = Join-Path $env:USERPROFILE "Documents\script.ps1"
                $result | Should -Be $expected
            }
        }

        Context "when handling edge cases" {
            It "handles empty relative path" {
                $result = Get-PlatformConfigPath "" "test.txt"

                $expected = Join-Path $env:USERPROFILE "test.txt"
                $result | Should -Be $expected
            }

            It "handles empty filename" {
                $result = Get-PlatformConfigPath ".config/test/" ""

                $expected = Join-Path $env:USERPROFILE ".config\test\"
                $result | Should -Be $expected
            }
        }
    }

    Describe "New-FileSymlink" {

        BeforeEach {
            # Create test source file
            $script:testSource = Join-Path $script:tempDir "source.txt"
            $script:testTarget = Join-Path $script:tempDir "target.txt"
            "Test content" | Set-Content $script:testSource

            # Clean up any existing target
            if (Test-Path $script:testTarget) {
                Remove-Item $script:testTarget -Force
            }
        }

        AfterEach {
            # Clean up test files
            if (Test-Path $script:testSource) {
                Remove-Item $script:testSource -Force
            }
            if (Test-Path $script:testTarget) {
                Remove-Item $script:testTarget -Force
            }
        }

        Context "when parameters are provided" {
            It "validates required parameters" {
                $result = New-FileSymlink "" $script:testSource
                $result | Should -Be $false

                $result = New-FileSymlink $script:testTarget ""
                $result | Should -Be $false

                $result = New-FileSymlink $null $script:testSource
                $result | Should -Be $false

                $result = New-FileSymlink $script:testTarget $null
                $result | Should -Be $false
            }
        }

        Context "when creating symlinks" {
            BeforeEach {
                # Mock cmd.exe to avoid actual mklink calls in tests
                Mock cmd.exe {
                    $global:LASTEXITCODE = 0
                    return "symbolic link created for $args"
                } -ModuleName $null
            }

            It "creates parent directory if it doesn't exist" {
                $nestedTarget = Join-Path $script:tempDir "nested\deep\target.txt"

                $result = New-FileSymlink $nestedTarget $script:testSource
                $result | Should -Be $true

                $parentDir = Split-Path $nestedTarget -Parent
                Test-Path $parentDir | Should -Be $true
            }

            It "removes existing file before creating symlink" {
                # Create existing file at target location
                "Existing content" | Set-Content $script:testTarget

                $result = New-FileSymlink $script:testTarget $script:testSource
                $result | Should -Be $true

                # Should have called mklink (mocked)
                Should -Invoke cmd.exe -Times 1
            }

            It "calls mklink with correct parameters" {
                $result = New-FileSymlink $script:testTarget $script:testSource
                $result | Should -Be $true

                Should -Invoke cmd.exe -Times 1 -ParameterFilter {
                    $args -contains "/c" -and
                    $args -match "mklink.*`"$([regex]::Escape($script:testTarget))`".*`"$([regex]::Escape($script:testSource))`""
                }
            }

            It "returns true on successful symlink creation" {
                $result = New-FileSymlink $script:testTarget $script:testSource

                $result | Should -Be $true
            }
        }

        Context "when mklink fails" {
            BeforeEach {
                # Mock cmd.exe to simulate failure
                Mock cmd.exe {
                    $global:LASTEXITCODE = 1
                    return "Access denied or Developer Mode not enabled"
                } -ModuleName $null
            }

            It "returns false on mklink failure" {
                $result = New-FileSymlink $script:testTarget $script:testSource

                $result | Should -Be $false
            }

            It "provides helpful error messages" {
                # Mock logging functions to capture error messages
                Mock Write-LogError { }

                $result = New-FileSymlink $script:testTarget $script:testSource
                $result | Should -Be $false

                Should -Invoke Write-LogError -Times 1 -ParameterFilter {
                    $Message -match "Failed to create symlink"
                }

                Should -Invoke Write-LogError -Times 1 -ParameterFilter {
                    $Message -match "Ensure Windows prerequisites are met"
                }
            }
        }

        Context "when mklink throws exceptions" {
            BeforeEach {
                # Mock cmd.exe to throw an exception
                Mock cmd.exe { throw "Command not found" } -ModuleName $null
            }

            It "handles exceptions gracefully" {
                $result = New-FileSymlink $script:testTarget $script:testSource

                $result | Should -Be $false
            }
        }
    }

    Describe "Integration scenarios" {

        Context "when combining functions" {
            It "can use Get-PlatformConfigPath output with New-FileSymlink" {
                # Mock mklink to avoid actual symlink creation
                Mock cmd.exe {
                    $global:LASTEXITCODE = 0
                    return "symbolic link created"
                } -ModuleName $null

                $configPath = Get-PlatformConfigPath ".config/test/" "config.json"
                $sourceFile = Join-Path $script:tempDir "source_config.json"
                "Test config" | Set-Content $sourceFile

                $result = New-FileSymlink $configPath $sourceFile

                $result | Should -Be $true
                Should -Invoke cmd.exe -Times 1
            }
        }
    }
}

