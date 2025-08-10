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

    # Pass arguments to setup.sh:
    .\setup.ps1 user
    .\setup.ps1 server --dry-run

.NOTES
    Requires Windows 10/11 with winget installed (comes by default)
#>

param(
    [switch]$SkipGitInstall,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$SetupArgs
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8

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
    
    Write-Step "Running setup.sh script in Git Bash..."
    
    # Get the directory where this script is located
    $scriptDir = Split-Path -Parent $MyInvocation.PSCommandPath
    if (-not $scriptDir) {
        # If running from iex, use current directory
        $scriptDir = Get-Location
    }
    
    $setupPath = Join-Path $scriptDir "setup.sh"
    
    if (-not (Test-Path $setupPath)) {
        Write-Error "setup.sh script not found at: $setupPath"
        Write-Host "Please ensure you're running this script from the laingville repository directory"
        exit 1
    }
    
    # Convert Windows path to Unix-style path for Git Bash
    $unixPath = $scriptDir -replace '\\', '/' -replace '^([A-Z]):', '/$1'
    
    # Build arguments string for setup.sh
    $argsString = ""
    if ($SetupArgs -and $SetupArgs.Count -gt 0) {
        $argsString = " " + ($SetupArgs -join " ")
    }
    
    # Change to repo directory and run setup.sh with arguments
    $bashCommand = "cd '$unixPath' && ./setup.sh$argsString"
    
    Write-Host "Executing: $bashCommand" -ForegroundColor DarkGray
    
    # Run Git Bash with the setup script
    & $GitBash -c $bashCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nSetup completed successfully!" -ForegroundColor Green
    }
    else {
        Write-Warning "Setup exited with code: $LASTEXITCODE"
    }
}

# Main execution
function Main {
    Write-Host @"

================================================================
              Laingville Windows Setup Script                 
================================================================
"@ -ForegroundColor Magenta

    # Step 1: Install or verify Git
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
    
    # Step 2: Run setup.sh in Git Bash
    Run-Setup -GitBash $gitBash
    
    Write-Host @"

================================================================
                      Setup Complete!                         
                                                              
  Your environment has been configured successfully.          
  You may need to restart your terminal for all changes      
  to take effect.                                            
================================================================
"@ -ForegroundColor Green
}

# Run the main function
Main