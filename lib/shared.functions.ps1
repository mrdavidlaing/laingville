[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()

# Shared PowerShell functions for setup scripts
# Core utilities and Windows-specific implementations

# Import specialized function modules
. "$PSScriptRoot\logging.functions.ps1"
. "$PSScriptRoot\security.functions.ps1"
. "$PSScriptRoot\yaml.functions.ps1"

# Wrapper functions for external commands (enables better testing/mocking)
function Invoke-Scoop {
    param([array]$Arguments)
    & scoop @Arguments
}

function Invoke-Winget {
    param([array]$Arguments)
    & winget @Arguments
}

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
                $result = Invoke-Winget @("install", "--id", $package, "-e", "--silent", "--accept-package-agreements", "--accept-source-agreements") 2>&1

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
    Removes packages using winget package manager
.PARAMETER Packages
    Array of package identifiers to remove
.DESCRIPTION
    Removes each package with proper error handling and progress reporting
.EXAMPLE
    Remove-WingetPackage @("Git.Git", "Microsoft.PowerShell")
#>
function Remove-WingetPackage {
    [CmdletBinding(SupportsShouldProcess)]
    param([string[]]$Packages)

    if (-not $Packages -or $Packages.Count -eq 0) {
        return $true
    }

    Write-Host "Removing winget packages: $($Packages -join ', ')" -ForegroundColor Cyan

    foreach ($package in $Packages) {
        if ($package) {
            Write-Host "Removing: $package" -ForegroundColor Yellow
            try {
                $result = Invoke-Winget @("uninstall", "--id", $package, "-e", "--silent") 2>&1

                # Handle different exit codes
                switch ($LASTEXITCODE) {
                    0 {
                        Write-Host "[OK] Removed: $package" -ForegroundColor Green
                    }
                    -1978335212 {
                        # Package not found (already removed)
                        Write-Host "[OK] Not installed: $package" -ForegroundColor Green
                    }
                    -1978335184 {
                        # Uninstaller error (exit code 1603) - typically means app is running or locked
                        Write-Warning "Failed to remove $package (exit code: $LASTEXITCODE - uninstaller error)"
                        Write-Warning "This usually means:"
                        Write-Warning "  - The application is currently running (close it and try again)"
                        Write-Warning "  - Files are locked by another process"
                        Write-Warning "  - Insufficient permissions"
                        if ($result -and $result.ToString().Length -lt 500) {
                            Write-Host "$result" -ForegroundColor Red
                        }
                    }
                    default {
                        Write-Warning "Failed to remove $package (exit code: $LASTEXITCODE)"
                        if ($result -and $result.ToString().Length -lt 500) {
                            Write-Host "$result" -ForegroundColor Red
                        }
                    }
                }
            }
            catch {
                Write-Warning "Error removing ${package}: $($_.Exception.Message)"
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
                }
                else {
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
    Removes PowerShell modules
.PARAMETER Modules
    Array of module names to remove
.DESCRIPTION
    Removes each PowerShell module with proper error handling
.EXAMPLE
    Remove-PowerShellModule @("Pester", "PSReadLine")
#>
function Remove-PowerShellModule {
    [CmdletBinding(SupportsShouldProcess)]
    param([string[]]$Modules)

    if (-not $Modules -or $Modules.Count -eq 0) {
        return $true
    }

    Write-Host "Removing PowerShell modules: $($Modules -join ', ')" -ForegroundColor Cyan

    foreach ($module in $Modules) {
        if ($module) {
            Write-Host "Removing: $module" -ForegroundColor Yellow
            try {
                if (Get-Module -ListAvailable -Name $module) {
                    Uninstall-Module -Name $module -Force -ErrorAction Stop
                    Write-Host "[OK] Removed: $module" -ForegroundColor Green
                }
                else {
                    Write-Host "[OK] Not installed: $module" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "Error removing ${module}: $($_.Exception.Message)"
            }
        }
    }

    return $true
}

<#
.SYNOPSIS
    Installs packages using the Scoop package manager
.PARAMETER Packages
    Array of package identifiers to install (format: package or bucket/package)
.DESCRIPTION
    Installs each package with proper error handling and progress reporting
    Automatically installs Scoop if it's not already installed
    Automatically adds required buckets if packages specify them (e.g., versions/wezterm-nightly)
    Handles common exit codes and scenarios appropriately
.EXAMPLE
    Install-ScoopPackage @("git", "versions/wezterm-nightly", "extras/firefox")
#>
function Install-ScoopPackage {
    param([string[]]$Packages)

    if (-not $Packages -or $Packages.Count -eq 0) {
        return $true
    }

    # Check if Scoop is installed, install if not
    if (-not (Get-Command "scoop" -ErrorAction SilentlyContinue)) {
        Write-Host "Scoop is not installed. Installing Scoop..." -ForegroundColor Yellow

        try {
            # Set execution policy for current user (required for Scoop installation)
            Write-Host "Setting execution policy for current user..." -ForegroundColor Gray
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

            # Download and install Scoop
            Write-Host "Downloading and installing Scoop..." -ForegroundColor Gray
            $installScript = Invoke-RestMethod -Uri https://get.scoop.sh
            & ([scriptblock]::Create($installScript))

            # Verify installation
            if (Get-Command "scoop" -ErrorAction SilentlyContinue) {
                Write-Host "[OK] Scoop installed successfully" -ForegroundColor Green
            }
            else {
                Write-Warning "Scoop installation completed but command not found. Please restart your shell."
                return $false
            }
        }
        catch {
            Write-Warning "Failed to install Scoop: $($_.Exception.Message)"
            Write-Warning "Please install Scoop manually: https://scoop.sh"
            return $false
        }
    }

    Write-Host "Installing scoop packages: $($Packages -join ', ')" -ForegroundColor Cyan

    # Extract unique buckets from packages
    $bucketsToAdd = @()
    foreach ($package in $Packages) {
        if ($package -and $package.Contains('/')) {
            $bucket = $package.Split('/')[0]
            if ($bucket -notin $bucketsToAdd) {
                $bucketsToAdd += $bucket
            }
        }
    }

    # Get list of existing buckets to avoid unnecessary add attempts
    $existingBuckets = @()
    if ($bucketsToAdd.Count -gt 0) {
        try {
            $bucketList = Invoke-Scoop @("bucket", "list") 2>$null
            if ($LASTEXITCODE -eq 0 -and $bucketList) {
                $existingBuckets = $bucketList | Where-Object { $_.Name } | Select-Object -ExpandProperty Name
            }
        }
        catch {
            # If listing fails, continue with empty list (will attempt to add all buckets)
            # This is intentionally silent to avoid noise when scoop is not available
            Write-Debug "Failed to list buckets: $($_.Exception.Message)"
        }
    }

    # Add required buckets (only if they don't already exist)
    foreach ($bucket in $bucketsToAdd) {
        if ($bucket -in $existingBuckets) {
            Write-Host "[OK] Bucket already exists: $bucket" -ForegroundColor Green
        }
        else {
            Write-Host "Adding bucket: $bucket" -ForegroundColor Yellow
            try {
                $result = Invoke-Scoop @("bucket", "add", $bucket) 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Added bucket: $bucket" -ForegroundColor Green
                }
                else {
                    Write-Warning "Failed to add bucket $bucket (exit code: $LASTEXITCODE): $result"
                }
            }
            catch {
                Write-Warning "Error adding bucket ${bucket}: $($_.Exception.Message)"
            }
        }
    }

    # Install packages
    foreach ($package in $Packages) {
        if ($package) {
            # Check if package is already installed
            $packageName = if ($package -match '/') {
                ($package -split '/')[-1]
            }
            else {
                $package
            }

            try {
                $listResult = Invoke-Scoop @("list", $packageName) 2>$null
                $isInstalled = $LASTEXITCODE -eq 0 -and $listResult
            }
            catch {
                # If listing fails, assume package is not installed
                $isInstalled = $false
            }

            if ($isInstalled) {
                Write-Host "Updating existing package: $package" -ForegroundColor Cyan
                try {
                    $null = Invoke-Scoop @("update", $package) 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "[OK] Updated: $package" -ForegroundColor Green
                    }
                    else {
                        Write-Host "[OK] Already up-to-date: $package" -ForegroundColor Green
                    }
                }
                catch {
                    Write-Host "[OK] Already installed (update failed): $package" -ForegroundColor Green
                }
            }
            else {
                Write-Host "Installing: $package" -ForegroundColor Yellow
                try {
                    $result = Invoke-Scoop @("install", $package) 2>&1

                    # Handle different scenarios
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "[OK] Installed: $package" -ForegroundColor Green
                    }
                    elseif ($result -like "*not found*") {
                        Write-Warning "Package not found: $package"
                    }
                    else {
                        Write-Warning "Failed to install $package (exit code: $LASTEXITCODE)"
                        # Only show detailed output for actual errors
                        if ($result -and $result.ToString().Length -lt 500) {
                            Write-Host "$result" -ForegroundColor Red
                        }
                    }
                }
                catch {
                    Write-Warning "Error installing ${package}: $($_.Exception.Message)"
                }
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

<#
.SYNOPSIS
    Removes packages using Scoop package manager
.PARAMETER Packages
    Array of package identifiers to remove
.DESCRIPTION
    Removes each package with proper error handling
.EXAMPLE
    Remove-ScoopPackage @("git", "versions/wezterm-nightly")
#>
function Remove-ScoopPackage {
    [CmdletBinding(SupportsShouldProcess)]
    param([string[]]$Packages)

    if (-not $Packages -or $Packages.Count -eq 0) {
        return $true
    }

    # Check if scoop is available
    if (-not (Get-Command "scoop" -ErrorAction SilentlyContinue)) {
        Write-Warning "Scoop not found, skipping scoop package removal"
        return $true
    }

    Write-Host "Removing scoop packages: $($Packages -join ', ')" -ForegroundColor Cyan

    foreach ($package in $Packages) {
        if ($package) {
            # Extract package name (remove bucket prefix if present)
            $packageName = if ($package -match "/") {
                $package.Split("/")[1]
            }
            else {
                $package
            }

            Write-Host "Removing: $packageName" -ForegroundColor Yellow
            try {
                $null = Invoke-Scoop @("uninstall", $packageName) 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Removed: $packageName" -ForegroundColor Green
                }
                else {
                    Write-Warning "Failed to remove $packageName (exit code: $LASTEXITCODE)"
                }
            }
            catch {
                Write-Warning "Error removing ${packageName}: $($_.Exception.Message)"
            }
        }
    }

    return $true
}
