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
. "$LibDir\security.functions.ps1"
. "$LibDir\shared.functions.ps1"
. "$LibDir\setup-user.functions.ps1"

# Check for administrator privileges and auto-elevate if needed
if (-not (Test-Administrator)) {
    Write-Host "Administrator privileges required for package operations..." -ForegroundColor Yellow
    Write-Host "Restarting with elevated privileges..." -ForegroundColor Yellow
    Write-Host ""

    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($DryRun) {
        $arguments += " -DryRun"
    }

    # Start elevated process and wait for it to complete
    Start-Process pwsh -Verb RunAs -ArgumentList $arguments -Wait

    # After elevated process completes, show WSL instructions in original console
    Write-Host ""
    Write-Host "Windows setup completed in elevated window." -ForegroundColor Green
    Write-Host ""

    # Check if WSL is available and show instructions
    if (Get-Command "wsl.exe" -ErrorAction SilentlyContinue) {
        $wslPath = $ProjectRoot -replace '^([A-Z]):', '/mnt/$1' -replace '\\', '/' | ForEach-Object { $_.ToLower() }
        $setupScript = "$wslPath/bin/setup-user"

        Write-Host "WSL SETUP:" -ForegroundColor Cyan
        Write-Host "----------" -ForegroundColor Cyan
        if ($DryRun) {
            Write-Host "To see what would be done in WSL, run:" -ForegroundColor White
            Write-Host "  wsl.exe -d archlinux bash `"$setupScript`" --dry-run" -ForegroundColor Yellow
        }
        else {
            Write-Host "To complete setup in WSL, run:" -ForegroundColor White
            Write-Host "  wsl.exe -d archlinux bash `"$setupScript`"" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    exit 0
}

# Print header
Write-Host "`nStarting setup-user (Administrator)" -ForegroundColor Blue -BackgroundColor Black
Write-Host "------------------------------------" -ForegroundColor Blue

if ($DryRun) {
    Write-LogInfo "DRY RUN MODE - No changes will be made"
}

try {
    # Execute main user setup
    $result = Invoke-UserSetup -DryRun:$DryRun

    if ($result) {
        if ($DryRun) {
            Write-Host "`nDry run completed successfully!" -ForegroundColor Green
        }
        else {
            Write-Host "`nUser setup completed successfully!" -ForegroundColor Green
        }
        exit 0
    }
    else {
        Write-Host "`nUser setup failed!" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-LogError "Unhandled exception: $_"
    Write-LogError $_.ScriptStackTrace
    exit 1
}
