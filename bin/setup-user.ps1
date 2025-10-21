#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Windows PowerShell user setup script - creates symlinks and installs packages

.DESCRIPTION
    This is the Windows PowerShell implementation of the user setup script.
    It mirrors the functionality of the bash version but uses Windows-native
    implementations to avoid Git Bash path conversion issues.

.PARAMETER DryRun
    Preview what changes would be made without actually making them

.EXAMPLE
    # Standard usage:
    .\setup-user.ps1

    # Preview mode:
    .\setup-user.ps1 -DryRun

.NOTES
    Requires Windows 10/11 with Developer Mode enabled for symlink creation
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param(
    [switch]$DryRun,
    [string]$TranscriptPath
)

$ErrorActionPreference = "Stop"

# Get script paths
$ScriptDir = Split-Path $PSCommandPath -Parent
$ProjectRoot = Split-Path $ScriptDir -Parent
$LibDir = Join-Path $ProjectRoot "lib"

# Source functions
. "$LibDir\security.functions.ps1"
. "$LibDir\shared.functions.ps1"
. "$LibDir\setup-user.functions.ps1"
. "$LibDir\claudecode.functions.ps1"

# Check for administrator privileges and auto-elevate if needed
if (-not (Test-Administrator)) {
    Write-Host "Administrator privileges required for package operations..." -ForegroundColor Yellow
    Write-Host "Restarting with elevated privileges..." -ForegroundColor Yellow
    Write-Host ""

    # Create temp file for transcript capture
    $transcriptFile = Join-Path $env:TEMP "laingville-setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -TranscriptPath `"$transcriptFile`""
    if ($DryRun) {
        $arguments += " -DryRun"
    }

    # Start elevated process and wait for it to complete
    $process = Start-Process pwsh -Verb RunAs -ArgumentList $arguments -PassThru -Wait

    # After elevated process completes, display captured output
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "Output from elevated process:" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""

    if (Test-Path $transcriptFile) {
        Get-Content $transcriptFile
        Remove-Item $transcriptFile -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "Warning: Transcript file not found at $transcriptFile" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""

    # WSL instructions are already printed by Invoke-UserSetup in the transcript above
    exit $process.ExitCode
}

# Main execution logic - defined once, used with or without Tee-Object
$mainExecution = {
    # Print header
    Write-Host "`nStarting setup-user (Administrator)" -ForegroundColor Blue -BackgroundColor Black
    Write-Host "------------------------------------" -ForegroundColor Blue

    if ($DryRun) {
        Write-LogInfo "DRY RUN MODE - No changes will be made"
    }

    try {
        # Execute main user setup
        $result = Invoke-UserSetup -DryRun:$DryRun

        # Invoke-UserSetup already prints completion messages, just exit with appropriate code
        if ($result) { exit 0 } else { exit 1 }
    }
    catch {
        Write-LogError "Unhandled exception: $_"
        Write-LogError $_.ScriptStackTrace
        exit 1
    }
}

# Execute with or without transcript capture
if ($TranscriptPath) {
    & $mainExecution *>&1 | Tee-Object -FilePath $TranscriptPath
    exit $LASTEXITCODE
}
else {
    & $mainExecution
}
