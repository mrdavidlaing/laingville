[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
param()

# PowerShell Profile for mrdavidlaing
# This profile is automatically loaded when PowerShell starts

# Ensure Claude Code can locate Git Bash for native CLI integration
if (-not $env:CLAUDE_CODE_GIT_BASH_PATH -or -not (Test-Path $env:CLAUDE_CODE_GIT_BASH_PATH)) {
    $candidateRoots = @(
        $Env:ProgramFiles,
        ${Env:ProgramFiles(x86)}
    ) | Where-Object { $_ }

    $gitBashCandidates = @()
    foreach ($root in $candidateRoots) {
        $gitBashCandidates += @(
            Join-Path $root 'Git\bin\bash.exe'
            Join-Path $root 'Git\usr\bin\bash.exe'
        )
    }

    foreach ($candidate in $gitBashCandidates) {
        if (Test-Path $candidate) {
            $env:CLAUDE_CODE_GIT_BASH_PATH = $candidate
            break
        }
    }

    if (-not $env:CLAUDE_CODE_GIT_BASH_PATH) {
        $gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
        if ($gitCommand) {
            $gitRoot = Split-Path $gitCommand.Path -Parent
            $gitRootBase = Split-Path $gitRoot -Parent
            $derivedCandidate = Join-Path $gitRootBase 'bin\bash.exe'
            if (Test-Path $derivedCandidate) {
                $env:CLAUDE_CODE_GIT_BASH_PATH = $derivedCandidate
            }
        }
    }

    if ($env:CLAUDE_CODE_GIT_BASH_PATH) {
        Write-Verbose "CLAUDE_CODE_GIT_BASH_PATH set to $($env:CLAUDE_CODE_GIT_BASH_PATH)"
    }
    else {
        Write-Verbose 'CLAUDE_CODE_GIT_BASH_PATH not set; Git Bash was not found automatically.'
    }
}

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
