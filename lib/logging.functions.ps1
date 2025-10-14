[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()

# Logging functions for PowerShell setup scripts
# Provides consistent logging across all scripts

<#
.SYNOPSIS
    Writes an informational message to the console
.PARAMETER Message
    The message to display
#>
function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor White
}

<#
.SYNOPSIS
    Writes a success message to the console
.PARAMETER Message
    The message to display
#>
function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

<#
.SYNOPSIS
    Writes a warning message to the console
.PARAMETER Message
    The message to display
#>
function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

<#
.SYNOPSIS
    Writes an error message to the console
.PARAMETER Message
    The message to display
#>
function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

<#
.SYNOPSIS
    Writes a step header with underline
.PARAMETER Message
    The step title to display
#>
function Write-Step {
    param([string]$Message)
    # Call Write-Host twice directly (avoiding nested function calls)
    Write-Host "`n$Message" -ForegroundColor Cyan
    $underline = "-" * $Message.Length
    Write-Host $underline -ForegroundColor Cyan
}
