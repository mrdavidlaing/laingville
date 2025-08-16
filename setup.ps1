#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Windows setup script that ensures Git Bash is available then runs setup.sh

.DESCRIPTION
    This is the Windows entry point for Laingville setup. It ensures Git for Windows
    (which includes Git Bash) is installed, then delegates to setup.sh. Use this
    script when running from PowerShell on Windows.

.EXAMPLE
    # Standard usage from PowerShell:
    .\setup.ps1

    # Skip Git installation check if you know it's already installed:
    .\setup.ps1 -SkipGitInstall

    # Run user setup in dry-run mode:
    .\setup.ps1 -Target user -DryRun

    # Run server setup:
    .\setup.ps1 -Target server

.NOTES
    Requires Windows 10/11 with winget installed (comes by default)
#>

param(
    [switch]$SkipGitInstall,
    [switch]$DryRun,
    [ValidateSet("user", "server")]
    [string]$Target = "user",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AdditionalArgs
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8

# Check for incorrect bash-style syntax and provide helpful error
if ($AdditionalArgs -contains "--dry-run") {
    Write-Error "Use PowerShell syntax: -DryRun (not --dry-run)"
    Write-Host "Example: .\setup.ps1 -Target user -DryRun" -ForegroundColor Yellow
    exit 1
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n===> $Message" -ForegroundColor Cyan
}

function Test-Command {
    param([string]$Command)
    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

function Test-GitBash {
    $gitPath = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "$env:ProgramFiles(x86)\Git\bin\bash.exe",
        "${env:LOCALAPPDATA}\Programs\Git\bin\bash.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    return $gitPath
}

function Test-WSLFeature {
    # Simple check - if wsl.exe exists and responds to --list, WSL is available
    if (Get-Command "wsl.exe" -ErrorAction SilentlyContinue) {
        try {
            # Use --list which should work even with no distributions
            $output = & wsl.exe --list --quiet 2>&1
            # If WSL is working, it should return successfully even with empty list
            return ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null)
        }
        catch {
            return $false
        }
    }
    return $false
}

function Test-DeveloperMode {
    # Check registry for Developer Mode setting
    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
        $allowDeveloperUnlock = Get-ItemProperty -Path $regPath -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
        return ($allowDeveloperUnlock.AllowDevelopmentWithoutDevLicense -eq 1)
    }
    catch {
        return $false
    }
}

function Enable-DeveloperMode {
    Write-Step "Developer Mode is required for symbolic link creation..."
    Write-Host "Please enable Developer Mode manually in Windows Settings."
    return $false
}

function Ensure-WindowsPrerequisites {
    Write-Step "Checking Windows prerequisites for dotfile management..."
    
    $prerequisitesMet = $true
    
    # Check WSL feature (needed for Arch Linux configuration)
    if (-not (Test-WSLFeature)) {
        Write-Host "WSL feature is not enabled." -ForegroundColor Red
        Write-Host ""
        Write-Host "To enable WSL:" -ForegroundColor Yellow
        Write-Host "1. Open PowerShell as Administrator" -ForegroundColor Yellow
        Write-Host "2. Run: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All" -ForegroundColor Yellow
        Write-Host "3. Restart your computer when prompted" -ForegroundColor Yellow
        Write-Host "4. Run this script again after restart" -ForegroundColor Yellow
        Write-Host ""
        $prerequisitesMet = $false
    } else {
        Write-Host "WSL feature is enabled" -ForegroundColor Green
    }
    
    # Check Developer Mode
    if (-not (Test-DeveloperMode)) {
        Write-Host "Developer Mode is not enabled (required for symbolic links)." -ForegroundColor Red
        Write-Host ""
        Write-Host "To enable Developer Mode:" -ForegroundColor Yellow
        Write-Host "1. Open Windows Settings (Win + I)" -ForegroundColor Yellow
        Write-Host "2. Go to Update & Security > For developers" -ForegroundColor Yellow
        Write-Host "3. Turn on 'Developer Mode'" -ForegroundColor Yellow
        Write-Host "4. Run this script again after enabling" -ForegroundColor Yellow
        Write-Host ""
        $prerequisitesMet = $false
    } else {
        Write-Host "Developer Mode is enabled" -ForegroundColor Green
    }
    
    if ($prerequisitesMet) {
        Write-Host "All Windows prerequisites are satisfied!" -ForegroundColor Green
    } else {
        Write-Host "Please satisfy the prerequisites above and run this script again." -ForegroundColor Red
        exit 1
    }
}

function Install-Git {
    Write-Step "Checking for Git installation..."
    
    $gitBash = Test-GitBash
    if ($gitBash -and (Test-Command "git")) {
        Write-Host "Git is already installed at: $gitBash" -ForegroundColor Green
        return $gitBash
    }
    
    Write-Step "Installing Git for Windows via winget..."
    
    # Check if winget is available
    if (-not (Test-Command "winget")) {
        Write-Error "winget is not available. Please install App Installer from the Microsoft Store."
        exit 1
    }
    
    try {
        # Install Git using winget
        winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
        
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + 
                    [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Wait a moment for installation to complete
        Start-Sleep -Seconds 3
        
        # Find Git Bash
        $gitBash = Test-GitBash
        if (-not $gitBash) {
            Write-Error "Git Bash not found after installation. Please install Git manually."
            exit 1
        }
        
        Write-Host "Git installed successfully!" -ForegroundColor Green
        return $gitBash
    }
    catch {
        Write-Error "Failed to install Git: $_"
        Write-Host "Please install Git manually from: https://git-scm.com/download/win"
        exit 1
    }
}


function Run-Setup {
    param([string]$GitBash)
    
    Write-Step "Running PowerShell setup scripts..."
    
    # Get the directory where this script is located
    $scriptDir = Split-Path -Parent $MyInvocation.PSCommandPath
    if (-not $scriptDir) {
        # If running from iex, use current directory
        $scriptDir = Get-Location
    }
    
    # Build script path using the Target parameter
    $scriptPath = Join-Path $scriptDir "bin\setup-$Target.ps1"
    
    if (-not (Test-Path $scriptPath)) {
        Write-Error "PowerShell script not found at: $scriptPath"
        Write-Host "Available scripts: setup-user.ps1, setup-server.ps1"
        exit 1
    }
    
    Write-Host "Executing: $scriptPath" -ForegroundColor Green
    
    try {
        # Execute the PowerShell script with parameters
        $params = @{}
        if ($DryRun) { $params.DryRun = $true }
        if ($AdditionalArgs) { $params.AdditionalArgs = $AdditionalArgs }
        
        & $scriptPath @params
        
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-Host "`nSetup completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "`nSetup failed with exit code: $exitCode" -ForegroundColor Red
            exit $exitCode
        }
    }
    catch {
        Write-Error "Failed to execute setup script: $_"
        exit 1
    }
}

# Main execution
function Main {
    Write-Host @"

================================================================
              Laingville Windows Setup Script                 
================================================================
"@ -ForegroundColor Magenta

    # Step 1: Ensure Windows prerequisites (WSL, Developer Mode)
    Ensure-WindowsPrerequisites

    # Step 2: Install or verify Git
    if (-not $SkipGitInstall) {
        $gitBash = Install-Git
    }
    else {
        $gitBash = Test-GitBash
        if (-not $gitBash) {
            Write-Error "Git Bash not found. Remove -SkipGitInstall flag or install Git manually."
            exit 1
        }
    }
    
    # Step 3: Provide setup instructions
    Run-Setup -GitBash $gitBash
}

# Run the main function
Main