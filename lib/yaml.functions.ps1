# YAML parsing functions for PowerShell setup scripts
# Provides simple YAML parsing for package and symlink configurations

<#
.SYNOPSIS
    Cleans and trims package names from YAML entries
.PARAMETER PackageName
    The raw package name string to clean
.DESCRIPTION
    Removes quotes, comments, and extra whitespace from package names
#>
function Format-PackageName {
    param([string]$PackageName)

    if (-not $PackageName) {
        return ""
    }

    return $PackageName.Trim().Trim('"').Trim("'")
}

<#
.SYNOPSIS
    Gets YAML list format item (lines starting with -)
.PARAMETER ListContent
    The raw content of a YAML list section
.DESCRIPTION
    Gets package names from YAML list format, handling comments and quotes
#>
function Get-YamlListItem {
    param([string]$ListContent)

    if (-not $ListContent) {
        return @()
    }

    return $ListContent -split "\r?\n" | ForEach-Object {
        if ($_ -match '^\s*-\s*(.+?)(?:\s*#.*)?$') {
            Format-PackageName $Matches[1]
        }
    } | Where-Object { $_ -and $_.Length -gt 0 }
}

<#
.SYNOPSIS
    Gets YAML inline array format [item1, item2, item3]
.PARAMETER ArrayContent
    The content inside the square brackets
.DESCRIPTION
    Gets package names from inline array format, handling quotes
#>
function Get-YamlInlineArray {
    param([string]$ArrayContent)

    if (-not $ArrayContent) {
        return @()
    }

    return $ArrayContent -split ',' | ForEach-Object {
        Format-PackageName $_
    } | Where-Object { $_ -and $_.Length -gt 0 }
}

<#
.SYNOPSIS
    Gets packages for a specific package manager type
.PARAMETER Section
    The platform section content (e.g., windows section)
.PARAMETER PackageType
    The package manager type (winget, scoop, psmodule)
.PARAMETER AllTypes
    Array of all package manager types for lookahead pattern
.DESCRIPTION
    Generic function to get packages for any package manager type
#>
function Get-PackageSection {
    param(
        [string]$Section,
        [string]$PackageType,
        [array]$AllTypes
    )

    if (-not $Section -or -not $PackageType) {
        return @()
    }

    # Create lookahead pattern excluding current type
    $otherTypes = $AllTypes | Where-Object { $_ -ne $PackageType }
    $lookahead = if ($otherTypes.Count -gt 0) { "(?=\s*(?:$($otherTypes -join '|')):|$)" } else { "(?=$)" }

    # Try list format first
    if ($Section -match "$PackageType`:\s*\r?\n((?:\s+.*\r?\n?)*?)$lookahead") {
        return Get-YamlListItem $Matches[1]
    }
    # Try inline array format
    elseif ($Section -match "$PackageType`:\s*\[(.*?)\]") {
        return Get-YamlInlineArray $Matches[1]
    }

    return @()
}

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
        [string]$YamlFile
    )

    if (-not (Test-Path $YamlFile)) {
        return @{}
    }

    $packages = @{
        pacman           = @()
        aur              = @()
        winget           = @()
        scoop            = @()
        psmodule         = @()
        winget_cleanup   = @()
        scoop_cleanup    = @()
        psmodule_cleanup = @()
        custom           = @()
    }

    try {
        $content = Get-Content $YamlFile -Raw

        # Simple YAML parsing for Windows packages
        if ($content -match "windows:\s*\r?\n((?:\s+.*\r?\n?)*)") {
            $windowsSection = $Matches[1]

            # Extract packages for all Windows package managers using helper functions
            $packageTypes = @('winget', 'scoop', 'psmodule', 'winget_cleanup', 'scoop_cleanup', 'psmodule_cleanup', 'custom')
            foreach ($packageType in $packageTypes) {
                $packages.$packageType = Get-PackageSection -Section $windowsSection -PackageType $packageType -AllTypes $packageTypes
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
        if ($content -match "${Platform}:\s*\r?\n((?:\s+[^\r\n]+(?:\r?\n|$))*)") {
            $platformSection = $Matches[1]

            # Split into lines and process each symlink entry
            $lines = $platformSection -split "\r?\n" | Where-Object { $_.Trim() -ne "" }

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
                    }
                    else {
                        # Simple string entry - both source and target are the same
                        $entry = @{
                            source = $value
                            target = $value
                        }
                        $symlinks += $entry
                    }
                }
                elseif ($line -match "^\s+target:\s*(.+)$" -and $currentEntry) {
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

    return , $symlinks
}
