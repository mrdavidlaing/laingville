# PowerShell tests for security.functions.ps1
# Uses Pester BDD syntax similar to ShellSpec

BeforeAll {
    # Import the functions to test
    . "$PSScriptRoot/../../lib/security.functions.ps1"
}

Describe "security.functions.ps1" {
    
    Describe "Test-SafeFilename" {
        
        Context "when filename is valid" {
            It "accepts simple alphanumeric filenames" {
                $result = Test-SafeFilename "config.txt"
                $result | Should -Be $true
            }
            
            It "accepts filenames with underscores and hyphens" {
                $result = Test-SafeFilename "my_config-file.json"
                $result | Should -Be $true
            }
            
            It "accepts filenames with dots (but not path traversal)" {
                $result = Test-SafeFilename "version.1.0.txt"
                $result | Should -Be $true
            }
            
            It "accepts filenames with spaces" {
                $result = Test-SafeFilename "My Document.docx"
                $result | Should -Be $true
            }
        }
        
        Context "when filename contains dangerous characters" {
            It "rejects filenames with path traversal (..) sequences" {
                $result = Test-SafeFilename "..\\malicious.txt"
                $result | Should -Be $false
            }
            
            It "rejects filenames with forward slashes" {
                $result = Test-SafeFilename "path/traversal.txt"
                $result | Should -Be $false
            }
            
            It "rejects filenames with backslashes" {
                $result = Test-SafeFilename "path\\traversal.txt"
                $result | Should -Be $false
            }
            
            It "rejects filenames with angle brackets" {
                $result = Test-SafeFilename "file<script>.txt"
                $result | Should -Be $false
                
                $result = Test-SafeFilename "file>output.txt"
                $result | Should -Be $false
            }
            
            It "rejects filenames with pipe characters" {
                $result = Test-SafeFilename "file|command.txt"
                $result | Should -Be $false
            }
            
            It "rejects filenames with question marks" {
                $result = Test-SafeFilename "file?.txt"
                $result | Should -Be $false
            }
            
            It "rejects filenames with asterisks" {
                $result = Test-SafeFilename "file*.txt"
                $result | Should -Be $false
            }
            
            It "rejects filenames with colons" {
                $result = Test-SafeFilename "file:stream.txt"
                $result | Should -Be $false
            }
            
            It "rejects filenames with quotes" {
                $result = Test-SafeFilename 'file"quote.txt'
                $result | Should -Be $false
            }
            
            It "rejects filenames with command injection characters" {
                $result = Test-SafeFilename "file^command.txt"
                $result | Should -Be $false
                
                $result = Test-SafeFilename "file``command.txt"
                $result | Should -Be $false
                
                $result = Test-SafeFilename "file;command.txt"
                $result | Should -Be $false
            }
        }
        
        Context "when filename has invalid properties" {
            It "rejects empty filenames" {
                $result = Test-SafeFilename ""
                $result | Should -Be $false
            }
            
            It "rejects null filenames" {
                $result = Test-SafeFilename $null
                $result | Should -Be $false
            }
            
            It "rejects extremely long filenames" {
                $longFilename = "a" * 256  # 256 characters
                $result = Test-SafeFilename $longFilename
                $result | Should -Be $false
            }
            
            It "accepts filenames at the length limit" {
                $maxFilename = "a" * 255  # 255 characters
                $result = Test-SafeFilename $maxFilename
                $result | Should -Be $true
            }
        }
    }
    
    Describe "Test-SafePath" {
        
        Context "when path is within user home directory" {
            It "accepts paths within USERPROFILE" {
                $testPath = Join-Path $env:USERPROFILE "Documents\config.txt"
                
                $result = Test-SafePath $testPath
                
                $result | Should -Be $true
            }
            
            It "accepts paths within APPDATA" {
                $testPath = Join-Path $env:APPDATA "MyApp\config.json"
                
                $result = Test-SafePath $testPath
                
                $result | Should -Be $true
            }
            
            It "accepts paths within LOCALAPPDATA" {
                $testPath = Join-Path $env:LOCALAPPDATA "MyApp\data.db"
                
                $result = Test-SafePath $testPath
                
                $result | Should -Be $true
            }
            
            It "accepts relative paths that resolve within user home" {
                $originalLocation = Get-Location
                try {
                    Set-Location $env:USERPROFILE
                    
                    $result = Test-SafePath "Documents\test.txt"
                    
                    $result | Should -Be $true
                }
                finally {
                    Set-Location $originalLocation
                }
            }
        }
        
        Context "when path is within allowed base directory" {
            It "accepts paths within specified base directory" {
                $baseDir = $env:TEMP
                $testPath = Join-Path $baseDir "myapp\config.txt"
                
                $result = Test-SafePath $testPath -AllowedBase $baseDir
                
                $result | Should -Be $true
            }
            
            It "rejects paths outside specified base directory" {
                $baseDir = $env:TEMP
                $testPath = "C:\Windows\System32\dangerous.exe"
                
                $result = Test-SafePath $testPath -AllowedBase $baseDir
                
                $result | Should -Be $false
            }
        }
        
        Context "when path has security issues" {
            It "rejects empty paths" {
                $result = Test-SafePath ""
                $result | Should -Be $false
            }
            
            It "rejects null paths" {
                $result = Test-SafePath $null
                $result | Should -Be $false
            }
            
            It "rejects invalid path characters" {
                $invalidPath = "C:\Invalid|Path?.txt"
                
                $result = Test-SafePath $invalidPath
                
                $result | Should -Be $false
            }
            
            It "rejects paths outside user directories when AllowUserHome is true" {
                $systemPath = "C:\Windows\System32\file.txt"
                
                $result = Test-SafePath $systemPath -AllowUserHome $true
                
                $result | Should -Be $false
            }
        }
        
        Context "when AllowUserHome is disabled" {
            It "rejects paths within user home when disabled" {
                $testPath = Join-Path $env:USERPROFILE "Documents\config.txt"
                
                $result = Test-SafePath $testPath -AllowUserHome $false
                
                $result | Should -Be $false
            }
            
            It "still accepts paths within allowed base directory" {
                $baseDir = $env:TEMP
                $testPath = Join-Path $baseDir "config.txt"
                
                $result = Test-SafePath $testPath -AllowedBase $baseDir -AllowUserHome $false
                
                $result | Should -Be $true
            }
        }
    }
    
    Describe "Test-Administrator" {
        
        Context "when checking administrator privileges" {
            It "returns a boolean value" {
                $result = Test-Administrator
                
                $result | Should -BeOfType [bool]
            }
            
            # Note: The actual result depends on how the test is run
            # We can't reliably test both true and false cases in all environments
            It "uses Windows security APIs correctly" {
                # This test verifies the function executes without error
                # The actual privilege level depends on the test execution context
                { Test-Administrator } | Should -Not -Throw
            }
        }
    }
}