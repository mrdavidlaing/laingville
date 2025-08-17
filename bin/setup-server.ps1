#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Windows PowerShell server setup script - installs packages and runs custom scripts

.DESCRIPTION
    This is the Windows PowerShell implementation of the server setup script.
    It mirrors the functionality of the bash version but uses Windows-native
    implementations for package management and script execution.

.PARAMETER DryRun
    Preview what changes would be made without actually making them

.PARAMETER Help
    Show usage information

.EXAMPLE
    # Standard usage:
    .\setup-server.ps1

    # Preview mode:
    .\setup-server.ps1 -DryRun

.NOTES
    Requires Windows 10/11 with winget installed
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param(
    [switch]$DryRun,
    [switch]$Help
)

if ($Help) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

$ErrorActionPreference = "Stop"

# Get script paths
$ScriptDir = Split-Path $PSCommandPath -Parent
$ProjectRoot = Split-Path $ScriptDir -Parent
$LibDir = Join-Path $ProjectRoot "lib"

# Source functions
. "$LibDir\shared.functions.ps1"
. "$LibDir\setup-server.functions.ps1"

# Print header
Write-Host "`nStarting setup-server" -ForegroundColor Blue -BackgroundColor Black
Write-Host "---------------------" -ForegroundColor Blue

if ($DryRun) {
    Write-LogInfo "DRY RUN MODE - No changes will be made"
}

try {
    # Execute main server setup
    $result = Invoke-ServerSetup -DryRun:$DryRun
    
    if ($result) {
        if ($DryRun) {
            Write-Host "`nServer dry run completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "`nServer setup completed successfully!" -ForegroundColor Green
        }
        exit 0
    } else {
        Write-Host "`nServer setup failed!" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-LogError "Unhandled exception: $_"
    Write-LogError $_.ScriptStackTrace
    
    Write-Host "`nAn unexpected error occurred. Re-run with -DryRun for a preview." -ForegroundColor Red
    exit 1
}