[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()

# PowerShell server setup functions - Windows-native implementation
# Mirrors functionality from setup-server.functions.bash

# Import shared functions
. "$PSScriptRoot\shared.functions.ps1"

# Map hostname to server directory
function Get-ServerDirectory {
    param([string]$Hostname)
    
    if (-not $Hostname) {
        $Hostname = Get-CurrentHostname
    }
    
    return "servers\$Hostname"
}

# Get server packages from packages.yaml file
function Get-ServerPackage {
    param(
        [string]$ServerDir
    )
    
    $packagesFile = Join-Path $ServerDir "packages.yaml"
    
    if (-not (Test-Path $packagesFile)) {
        return @{
            pacman = @()
            aur = @()
            winget = @()
        }
    }
    
    return Get-PackagesFromYaml $packagesFile
}

# Install server packages
function Install-ServerPackage {
    param(
        [string]$ServerDir,
        [bool]$DryRun = $false
    )
    
    $packagesFile = Join-Path $ServerDir "packages.yaml"
    
    if (-not (Test-Path $packagesFile)) {
        if ($DryRun) {
            Write-Host "SERVER PACKAGES:" -ForegroundColor White
            Write-Host "* Would: skip (no packages.yaml found)" -ForegroundColor Gray
        } else {
            Write-LogInfo "No server packages.yaml found, skipping package installation"
        }
        return $true
    }
    
    $packages = Get-ServerPackage $ServerDir
    
    if ($DryRun) {
        Write-Host "SERVER PACKAGES:" -ForegroundColor White
        if ($packages.winget.Count -gt 0) {
            foreach ($pkg in $packages.winget) {
                Write-Host "* Would: install winget package: $pkg" -ForegroundColor Cyan
            }
        } else {
            Write-Host "* Would: skip (no Windows server packages defined)" -ForegroundColor Gray
        }
        return $true
    }
    
    # Install winget packages
    if ($packages.winget.Count -gt 0) {
        Write-Step "Installing Server Packages"
        return Install-WingetPackage $packages.winget
    }
    
    return $true
}

# Get custom scripts from packages.yaml
function Get-ServerCustomScript {
    param(
        [string]$ServerDir,
        [string]$Platform = "windows"
    )
    
    $packagesFile = Join-Path $ServerDir "packages.yaml"
    
    if (-not (Test-Path $packagesFile)) {
        return @()
    }
    
    $scripts = @()
    
    try {
        $content = Get-Content $packagesFile -Raw
        
        # Simple YAML parsing for custom scripts under platform section
        if ($content -match "${Platform}:\s*\r?\n((?:\s+.*\r?\n?)*)" -or $content -match "${Platform}:\s*\n((?:\s+.*\n?)*)") {
            $platformSection = $Matches[1]
            
            # Extract custom scripts
            if ($platformSection -match "custom:\s*\r?\n((?:\s+-.*\r?\n?)*)" -or $platformSection -match "custom:\s*\[(.*?)\]") {
                if ($Matches[1] -match '\[(.*?)\]') {
                    # Handle inline array format
                    $scripts = $Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") }
                } else {
                    # Handle YAML list format
                    $scriptList = $Matches[1]
                    $scripts = $scriptList -split "\r?\n" | ForEach-Object {
                        if ($_ -match '^\s*-\s*(.+)$') {
                            $Matches[1].Trim().Trim('"').Trim("'")
                        }
                    } | Where-Object { $_ }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to parse custom scripts from ${packagesFile}: $_"
    }
    
    return $scripts
}

# Process custom server scripts
function Invoke-ServerCustomScript {
    param(
        [string]$ServerDir,
        [string]$Platform = "windows",
        [bool]$DryRun = $false
    )
    
    $scripts = Get-ServerCustomScript $ServerDir $Platform
    
    if ($scripts.Count -eq 0) {
        if ($DryRun) {
            Write-Host "CUSTOM SCRIPTS:" -ForegroundColor White
            Write-Host "* Would: skip (no custom scripts defined)" -ForegroundColor Gray
        } else {
            Write-LogInfo "No custom scripts defined for server"
        }
        return $true
    }
    
    if ($DryRun) {
        Write-Host "CUSTOM SCRIPTS:" -ForegroundColor White
        foreach ($script in $scripts) {
            Write-Host "* Would: execute: $script" -ForegroundColor Cyan
        }
        return $true
    }
    
    Write-Step "Running Custom Server Scripts"
    
    $success = $true
    foreach ($script in $scripts) {
        # Validate script name for security
        if (-not ($script -match '^[a-zA-Z0-9_.-]+$') -or $script.Contains('..') -or $script.Contains('/') -or $script.Contains('\')) {
            Write-LogError "Invalid script name contains illegal characters: $script"
            $success = $false
            continue
        }
        
        if ($script.Length -gt 50) {
            Write-LogError "Script name too long: $script"
            $success = $false
            continue
        }
        
        # Look for script in server directory
        $fullScriptPath = Join-Path $ServerDir $script
        
        if (-not (Test-Path $fullScriptPath)) {
            Write-LogError "Custom script not found: $fullScriptPath"
            $success = $false
            continue
        }
        
        Write-LogInfo "Executing custom script: $script"
        
        try {
            # Execute the script based on its extension
            $extension = [System.IO.Path]::GetExtension($script).ToLower()
            
            switch ($extension) {
                ".ps1" {
                    & PowerShell -ExecutionPolicy Bypass -File $fullScriptPath
                }
                ".bat" {
                    & cmd.exe /c $fullScriptPath
                }
                ".cmd" {
                    & cmd.exe /c $fullScriptPath
                }
                default {
                    # Try PowerShell for extensionless files
                    & PowerShell -ExecutionPolicy Bypass -File $fullScriptPath
                }
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "Completed custom script: $script"
            } else {
                Write-LogError "Custom script failed with exit code ${LASTEXITCODE}: $script"
                $success = $false
            }
        }
        catch {
            Write-LogError "Exception running custom script ${script}: $_"
            $success = $false
        }
    }
    
    return $success
}

# Main server setup function
function Invoke-ServerSetup {
    param(
        [bool]$DryRun = $false
    )
    
    $hostname = Get-CurrentHostname
    Write-LogInfo "Configuring server: $hostname"
    
    # Determine server directory
    $scriptRoot = Split-Path $PSScriptRoot -Parent
    $serverDir = Join-Path $scriptRoot (Get-ServerDirectory $hostname)
    $sharedServerDir = Join-Path $scriptRoot "servers\shared"
    
    Write-Step "Server Setup for $hostname"
    Write-LogInfo "Using server configs from: $serverDir"
    
    # Validation
    Write-Step "Validation"
    if (-not (Test-Path $serverDir)) {
        Write-LogError "Server directory not found: $serverDir"
        return $false
    }
    Write-LogSuccess "Server directory found"
    
    # Process shared server configurations first
    if (Test-Path $sharedServerDir) {
        Write-Step "Shared Server Configuration"
        
        # Install shared packages
        $sharedResult = Install-ServerPackage $sharedServerDir $DryRun
        if (-not $sharedResult) {
            Write-LogWarning "Shared server package installation encountered issues"
        }
        
        # Run shared custom scripts
        $sharedScriptResult = Invoke-ServerCustomScript $sharedServerDir "windows" $DryRun
        if (-not $sharedScriptResult) {
            Write-LogWarning "Shared server custom scripts encountered issues"
        }
    }
    
    # Process hostname-specific server configurations
    Write-Step "Host-Specific Server Configuration"
    
    # Install server packages
    $packageResult = Install-ServerPackage $serverDir $DryRun
    if (-not $packageResult) {
        Write-LogWarning "Server package installation encountered issues"
    }
    
    # Run custom scripts
    $scriptResult = Invoke-ServerCustomScript $serverDir "windows" $DryRun
    if (-not $scriptResult) {
        Write-LogWarning "Server custom scripts encountered issues"
    }
    
    # Success
    if ($DryRun) {
        Write-LogSuccess "Server dry run completed successfully"
    } else {
        Write-LogSuccess "Server setup completed successfully"
    }
    
    return $true
}