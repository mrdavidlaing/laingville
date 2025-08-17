# YAML parsing functions for PowerShell setup scripts
# Provides simple YAML parsing for package and symlink configurations

<#
.SYNOPSIS
    Extracts packages from YAML configuration files
.PARAMETER YamlFile
    Path to the YAML file containing package definitions
.PARAMETER Platform
    Platform section to extract packages from (default: "windows")
.DESCRIPTION
    Parses YAML files to extract package lists for specific platforms
#>
function Get-PackagesFromYaml {
    param(
        [string]$YamlFile,
        [string]$Platform = "windows"
    )
    
    if (-not (Test-Path $YamlFile)) {
        return @{}
    }
    
    $packages = @{
        pacman = @()
        aur = @()
        winget = @()
        psmodule = @()
    }
    
    try {
        $content = Get-Content $YamlFile -Raw
        
        # Simple YAML parsing for Windows packages
        if ($content -match "windows:\s*\r?\n((?:\s+.*\r?\n?)*)") {
            $windowsSection = $Matches[1]
            
            # Extract winget packages - look for winget: followed by list items
            if ($windowsSection -match "winget:\s*\r?\n((?:\s+-.*\r?\n?)*)") {
                $wingetList = $Matches[1]
                $wingetPackages = $wingetList -split "\r?\n" | ForEach-Object {
                    if ($_ -match '^\s*-\s*(.+)$') {
                        $Matches[1].Trim().Trim('"').Trim("'")
                    }
                } | Where-Object { $_ -and $_.Length -gt 0 }
                
                $packages.winget = $wingetPackages
            }
            # Also handle inline array format: winget: [package1, package2]
            elseif ($windowsSection -match "winget:\s*\[(.*?)\]") {
                $wingetPackages = $Matches[1] -split ',' | ForEach-Object { 
                    $_.Trim().Trim('"').Trim("'") 
                } | Where-Object { $_ -and $_.Length -gt 0 }
                
                $packages.winget = $wingetPackages
            }
            
            # Extract PowerShell modules - look for psmodule: followed by list items
            if ($windowsSection -match "psmodule:\s*\r?\n((?:\s+-.*\r?\n?)*)") {
                $psmoduleList = $Matches[1]
                $psmodulePackages = $psmoduleList -split "\r?\n" | ForEach-Object {
                    if ($_ -match '^\s*-\s*(.+)$') {
                        $Matches[1].Trim().Trim('"').Trim("'")
                    }
                } | Where-Object { $_ -and $_.Length -gt 0 }
                
                $packages.psmodule = $psmodulePackages
            }
            # Also handle inline array format: psmodule: [module1, module2]
            elseif ($windowsSection -match "psmodule:\s*\[(.*?)\]") {
                $psmodulePackages = $Matches[1] -split ',' | ForEach-Object { 
                    $_.Trim().Trim('"').Trim("'") 
                } | Where-Object { $_ -and $_.Length -gt 0 }
                
                $packages.psmodule = $psmodulePackages
            }
        }
    }
    catch {
        Write-Warning "Failed to parse YAML file ${YamlFile}: $_"
    }
    
    return $packages
}

<#
.SYNOPSIS
    Parses symlinks from YAML configuration files
.PARAMETER YamlFile
    Path to the YAML file containing symlink definitions
.PARAMETER Platform
    Platform section to extract symlinks from (default: "windows")
.DESCRIPTION
    Extracts symlink configurations for specific platforms from YAML files
    Returns array of hashtables with 'source' and 'target' keys
#>
function Get-SymlinksFromYaml {
    param(
        [string]$YamlFile,
        [string]$Platform = "windows"
    )
    
    if (-not (Test-Path $YamlFile)) {
        return @()
    }
    
    $symlinks = @()
    
    try {
        $content = Get-Content $YamlFile -Raw
        
        # Simple YAML parsing for platform section
        if ($content -match "${Platform}:\s*\r?\n((?:\s+.*\r?\n?)*)") {
            $platformSection = $Matches[1]
            
            # Split into lines and process each symlink entry
            $lines = $platformSection -split "\r?\n" | Where-Object { $_.Trim() }
            
            $currentEntry = $null
            foreach ($line in $lines) {
                # Skip if we hit another platform section
                if ($line -match "^[a-zA-Z]") {
                    break
                }
                
                # Process list items
                if ($line -match "^\s+-\s*(.+)$") {
                    $value = $Matches[1].Trim()
                    
                    # Check if it's a simple string or complex object
                    if ($value -match "^source:\s*(.+)$") {
                        # Start of complex object with source/target
                        $currentEntry = @{
                            source = $Matches[1].Trim()
                            target = $null
                        }
                    } else {
                        # Simple string entry - both source and target are the same
                        $symlinks += @{
                            source = $value
                            target = $value
                        }
                    }
                } elseif ($line -match "^\s+target:\s*(.+)$" -and $currentEntry) {
                    # Target line for complex object
                    $currentEntry.target = $Matches[1].Trim()
                    $symlinks += $currentEntry
                    $currentEntry = $null
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to parse symlinks YAML file ${YamlFile}: $_"
    }
    
    return $symlinks
}