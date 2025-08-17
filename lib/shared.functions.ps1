[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()

# Shared PowerShell functions for setup scripts
# Core utilities and Windows-specific implementations

# Import specialized function modules
. "$PSScriptRoot\logging.functions.ps1"
. "$PSScriptRoot\security.functions.ps1"
. "$PSScriptRoot\yaml.functions.ps1"

<#
.SYNOPSIS
    Installs packages using the Windows Package Manager (winget)
.PARAMETER Packages
    Array of package IDs to install
.DESCRIPTION
    Installs each package with proper error handling and progress reporting
    Handles common exit codes like "already installed" appropriately
.EXAMPLE
    Install-WingetPackage @("Git.Git", "Microsoft.PowerShell")
#>
function Install-WingetPackage {
    param([string[]]$Packages)
    
    if (-not $Packages -or $Packages.Count -eq 0) {
        return $true
    }
    
    Write-Host "Installing winget packages: $($Packages -join ', ')" -ForegroundColor Cyan
    
    foreach ($package in $Packages) {
        if ($package) {
            Write-Host "Installing: $package" -ForegroundColor Yellow
            try {
                $result = & winget install --id $package -e --silent --accept-package-agreements --accept-source-agreements 2>&1
                
                # Handle different exit codes
                switch ($LASTEXITCODE) {
                    0 {
                        Write-Host "[OK] Installed: $package" -ForegroundColor Green
                    }
                    -1978335189 {
                        # Package already installed and up-to-date
                        Write-Host "[OK] Already installed: $package" -ForegroundColor Green
                    }
                    -1978335212 {
                        # Package not found
                        Write-Warning "Package not found: $package"
                    }
                    default {
                        Write-Warning "Failed to install $package (exit code: $LASTEXITCODE)"
                        # Only show detailed output for actual errors
                        if ($result -and $result.ToString().Length -lt 500) {
                            Write-Host "$result" -ForegroundColor Red
                        }
                    }
                }
            }
            catch {
                Write-Warning "Error installing ${package}: $($_.Exception.Message)"
            }
        }
    }
    
    return $true
}

<#
.SYNOPSIS
    Installs PowerShell modules from PowerShell Gallery
.PARAMETER Modules
    Array of module names to install
.DESCRIPTION
    Installs each PowerShell module with proper error handling and progress reporting
    Uses Install-Module with appropriate flags for automation
.EXAMPLE
    Install-PowerShellModule @("Pester", "PSReadLine")
#>
function Install-PowerShellModule {
    param([string[]]$Modules)
    
    if (-not $Modules -or $Modules.Count -eq 0) {
        return $true
    }
    
    Write-Host "Installing PowerShell modules: $($Modules -join ', ')" -ForegroundColor Cyan
    
    foreach ($module in $Modules) {
        if ($module) {
            Write-Host "Installing PowerShell module: $module" -ForegroundColor Yellow
            try {
                # Check if we need to install/upgrade
                $latest = Find-Module -Name $module -ErrorAction SilentlyContinue
                $installed = Get-Module -Name $module -ListAvailable -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
                
                if ($installed -and $latest -and $installed.Version -ge $latest.Version) {
                    Write-Host "[OK] Already up-to-date: $module v$($installed.Version)" -ForegroundColor Green
                    continue
                }
                
                # Try to remove the module from memory if it's loaded
                $loadedModule = Get-Module -Name $module -ErrorAction SilentlyContinue
                if ($loadedModule) {
                    Write-Host "Unloading $module from memory..." -ForegroundColor Gray
                    Remove-Module -Name $module -Force -ErrorAction SilentlyContinue
                }
                
                Write-Host "Installing/upgrading to latest version of: $module" -ForegroundColor Gray
                
                # Install or upgrade module with appropriate flags
                Install-Module -Name $module -Force -SkipPublisherCheck -AllowClobber -Scope CurrentUser -ErrorAction Stop
                
                # Get the installed version to confirm
                $newInstalled = Get-Module -Name $module -ListAvailable -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
                if ($newInstalled) {
                    Write-Host "[OK] Installed/Updated: $module v$($newInstalled.Version)" -ForegroundColor Green
                } else {
                    Write-Host "[OK] Installed: $module" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "Failed to install PowerShell module $module`: $($_.Exception.Message)"
                return $false
            }
        }
    }
    
    return $true
}


<#
.SYNOPSIS
    Gets the current user and maps to dotfiles directory name
.DESCRIPTION
    Maps common usernames to their corresponding dotfiles directories
    Falls back to "shared" for unrecognized users
.EXAMPLE
    $user = Get-CurrentUser
#>
function Get-CurrentUser {
    # Get username, mapping special cases
    $username = $env:USERNAME.ToLower()
    
    switch ($username) {
        "timmy" { return "timmmmmmer" }
        "david" { return "mrdavidlaing" }
        "davidlaing" { return "mrdavidlaing" }
        default { return "shared" }
    }
}


<#
.SYNOPSIS
    Expands environment variables in Windows paths
.PARAMETER Path
    The path to expand
.DESCRIPTION
    Replaces environment variables like $APPDATA, $LOCALAPPDATA, $USERPROFILE
    For relative paths without environment variables, uses USERPROFILE as base
.EXAMPLE
    Expand-WindowsPath '$APPDATA\myapp\config.json'
#>
function Expand-WindowsPath {
    param([string]$Path)
    
    if (-not $Path) { return "" }
    
    # Replace common environment variables
    $expandedPath = $Path -replace '\$APPDATA', $env:APPDATA
    $expandedPath = $expandedPath -replace '\$LOCALAPPDATA', $env:LOCALAPPDATA
    $expandedPath = $expandedPath -replace '\$USERPROFILE', $env:USERPROFILE
    
    # If no environment variables were found and it's a relative path, use USERPROFILE as base
    if ($expandedPath -eq $Path -and -not [System.IO.Path]::IsPathRooted($expandedPath)) {
        $expandedPath = Join-Path $env:USERPROFILE $expandedPath
    }
    
    return $expandedPath
}

<#
.SYNOPSIS
    Gets the current computer hostname in lowercase
.DESCRIPTION
    Returns the computer name for server configuration mapping
.EXAMPLE
    $hostname = Get-CurrentHostname
#>
function Get-CurrentHostname {
    return $env:COMPUTERNAME.ToLower()
}

