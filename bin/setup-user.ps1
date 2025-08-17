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
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Get script paths
$ScriptDir = Split-Path $PSCommandPath -Parent
$ProjectRoot = Split-Path $ScriptDir -Parent
$LibDir = Join-Path $ProjectRoot "lib"

# Source functions
. "$LibDir\shared.functions.ps1"
. "$LibDir\setup-user.functions.ps1"

# Print header
Write-Host "`nStarting setup-user" -ForegroundColor Blue -BackgroundColor Black
Write-Host "--------------------" -ForegroundColor Blue

if ($DryRun) {
    Write-LogInfo "DRY RUN MODE - No changes will be made"
}

try {
    # Execute main user setup
    $result = Invoke-UserSetup -DryRun:$DryRun
    
    if ($result) {
        if ($DryRun) {
            Write-Host "`nDry run completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "`nUser setup completed successfully!" -ForegroundColor Green
        }
        exit 0
    } else {
        Write-Host "`nUser setup failed!" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-LogError "Unhandled exception: $_"
    Write-LogError $_.ScriptStackTrace
    exit 1
}