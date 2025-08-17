[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
param()

# PowerShell Profile for mrdavidlaing
# This profile is automatically loaded when PowerShell starts

# Initialize Starship prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# Set PowerShell to UTF-8
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# Enhanced PSReadLine configuration
if ($host.Name -eq 'ConsoleHost') {
    Import-Module PSReadLine
    
    # Set history search behavior
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    
    # Tab completion
    Set-PSReadLineKeyHandler -Key Tab -Function Complete
    
    # Enhanced prediction
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
}

# Useful aliases
Set-Alias -Name ll -Value Get-ChildItem
Set-Alias -Name la -Value Get-ChildItemAll
Set-Alias -Name grep -Value Select-String

# Custom function for ls -la equivalent
function Get-ChildItemAll {
    Get-ChildItem -Force @args
}

# Custom function for quick directory navigation
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }