# Security validation functions for PowerShell setup scripts
# Provides safe path and filename validation

<#
.SYNOPSIS
    Validates if a filename is safe for use in file operations
.PARAMETER Filename
    The filename to validate
.DESCRIPTION
    Checks for dangerous characters and length limits to prevent security issues
#>
function Test-SafeFilename {
    param([string]$Filename)

    if (-not $Filename) { return $false }

    # Check for dangerous characters
    $dangerousChars = @('..', '/', '\', '<', '>', ':', [char]34, [char]124, '?', '*', '^', [char]96, ';')

    foreach ($char in $dangerousChars) {
        if ($Filename.Contains($char)) {
            return $false
        }
    }

    # Check length
    if ($Filename.Length -gt 255) {
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Validates if a path is safe for file operations
.PARAMETER Path
    The path to validate
.PARAMETER AllowedBase
    Base directory that paths must be within
.PARAMETER AllowUserHome
    Whether to allow paths within user home directories
.DESCRIPTION
    Prevents path traversal attacks by ensuring paths stay within allowed boundaries
#>
function Test-SafePath {
    param(
        [string]$Path,
        [string]$AllowedBase,
        [bool]$AllowUserHome = $true
    )

    if (-not $Path) { return $false }

    # Resolve to absolute path
    try {
        # Handle relative paths more explicitly
        if ([System.IO.Path]::IsPathRooted($Path)) {
            $absolutePath = [System.IO.Path]::GetFullPath($Path)
        }
        else {
            # For relative paths, try to resolve against current directory first
            $currentDir = Get-Location -PSProvider FileSystem | Select-Object -ExpandProperty Path
            $absolutePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($currentDir, $Path))
        }
    }
    catch {
        return $false
    }

    # Check if within allowed base
    if ($AllowedBase) {
        $allowedBasePath = [System.IO.Path]::GetFullPath($AllowedBase)
        if ($absolutePath.StartsWith($allowedBasePath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
        else {
            return $false
        }
    }

    # Check if within user home directory
    if ($AllowUserHome) {
        $userHome = [System.IO.Path]::GetFullPath($env:USERPROFILE)
        if ($absolutePath.StartsWith($userHome, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }

        # Also allow AppData directories
        $appData = [System.IO.Path]::GetFullPath($env:APPDATA)
        $localAppData = [System.IO.Path]::GetFullPath($env:LOCALAPPDATA)

        if ($absolutePath.StartsWith($appData, [System.StringComparison]::OrdinalIgnoreCase) -or
            $absolutePath.StartsWith($localAppData, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

<#
.SYNOPSIS
    Tests if the current session is running with Administrator privileges
.DESCRIPTION
    Returns true if running as Administrator, false otherwise
#>
function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

