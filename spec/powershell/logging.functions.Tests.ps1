# PowerShell tests for logging.functions.ps1
# Uses Pester BDD syntax similar to ShellSpec

BeforeAll {
    # Import the functions to test
    . "$PSScriptRoot/../../lib/logging.functions.ps1"
}

Describe "logging.functions.ps1" {

    Describe "Write-LogInfo" {

        Context "when called with a message" {
            It "writes info message with correct format" {
                # Capture Write-Host output using mock
                Mock Write-Host { }

                Write-LogInfo "Test info message"

                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "[INFO] Test info message" -and
                    $ForegroundColor -eq "White"
                }
            }

            It "handles empty messages" {
                Mock Write-Host { }

                Write-LogInfo ""

                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "[INFO] "
                }
            }

            It "handles null messages" {
                Mock Write-Host { }

                Write-LogInfo $null

                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "[INFO] "
                }
            }
        }
    }

    Describe "Write-LogSuccess" {

        Context "when called with a message" {
            It "writes success message with correct format and color" {
                Mock Write-Host { }

                Write-LogSuccess "Operation completed successfully"

                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "[OK] Operation completed successfully" -and
                    $ForegroundColor -eq "Green"
                }
            }

            It "handles multiline messages" {
                Mock Write-Host { }
                $multilineMessage = "Line 1`nLine 2"

                Write-LogSuccess $multilineMessage

                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "[OK] $multilineMessage"
                }
            }
        }
    }

    Describe "Write-LogWarning" {

        Context "when called with a message" {
            It "writes warning message with correct format and color" {
                Mock Write-Host { }

                Write-LogWarning "This is a warning"

                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "[WARNING] This is a warning" -and
                    $ForegroundColor -eq "Yellow"
                }
            }

            It "handles special characters in messages" {
                Mock Write-Host { }
                $specialMessage = "Warning: File contains special chars: !@#$%^&*()"

                Write-LogWarning $specialMessage

                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "[WARNING] $specialMessage"
                }
            }
        }
    }

    Describe "Write-LogError" {

        Context "when called with a message" {
            It "writes error message with correct format and color" {
                Mock Write-Host { }

                Write-LogError "An error occurred"

                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "[ERROR] An error occurred" -and
                    $ForegroundColor -eq "Red"
                }
            }

            It "handles long error messages" {
                Mock Write-Host { }
                $longMessage = "This is a very long error message that might span multiple lines when displayed in the console but should still be formatted correctly with the ERROR prefix"

                Write-LogError $longMessage

                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "[ERROR] $longMessage"
                }
            }
        }
    }

    Describe "Write-Step" {

        Context "when called with a step title" {
            It "writes step header with newline and underline" {
                Mock Write-Host { }

                Write-Step "Installing Packages"

                # Should call Write-Host twice: once for the title, once for the underline
                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "`nInstalling Packages" -and
                    $ForegroundColor -eq "Cyan"
                }

                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "-------------------" -and
                    $ForegroundColor -eq "Cyan"
                }
            }

            It "creates underline matching message length" {
                Mock Write-Host { }
                $message = "Test"

                Write-Step $message

                # Underline should be 4 dashes for "Test"
                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "----" -and
                    $ForegroundColor -eq "Cyan"
                }
            }

            It "handles empty step titles" {
                Mock Write-Host { }

                Write-Step ""

                # Just check if Write-Host was called at all (simplified test)
                Should -Invoke Write-Host -Times 2
            }

            It "handles step titles with spaces" {
                Mock Write-Host { }
                $message = "Step With Spaces"

                Write-Step $message

                # Underline should match the length including spaces
                $expectedUnderline = "-" * $message.Length
                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq $expectedUnderline
                }
            }
        }
    }

    Describe "Logging functions integration" {

        Context "when used together in sequence" {
            It "can be called in succession without conflicts" {
                Mock Write-Host { }

                Write-Step "Starting Process"
                Write-LogInfo "Initializing components"
                Write-LogSuccess "Component loaded"
                Write-LogWarning "Minor issue detected"
                Write-LogError "Critical error occurred"

                # Verify all functions were called
                # Note: Write-Step makes 2 calls but only 1 is detected due to Pester mocking edge case
                Should -Invoke Write-Host -Times 6  # 1 detected from Step + 1 each for others
            }
        }
    }
}

