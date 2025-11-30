# Beads (bd) Installation Script for Windows
# Installs Beads using official PowerShell installer

# Suppress PSScriptAnalyzer warning for Invoke-Expression (required to execute official installer)
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Required to execute official beads installer script')]
param(
    [Parameter(Mandatory = $false)]
    [string]$DryRun = "false"
)

# Import shared functions
$libPath = Join-Path $PSScriptRoot ".." ".." ".." "lib" "logging.functions.ps1"
if (Test-Path $libPath) {
    . $libPath
}

if ($DryRun -eq "true") {
    if (Get-Command Write-StepMessage -ErrorAction SilentlyContinue) {
        Write-StepMessage "[Beads (bd)]" "[DRY RUN] Would install via PowerShell installer"
    }
    else {
        Write-Output "[Beads (bd)] [DRY RUN] Would install via PowerShell installer"
    }
    exit 0
}

if (Get-Command Write-StepMessage -ErrorAction SilentlyContinue) {
    # Using setup-user context with logging functions
    $useLogging = $true
}
else {
    # Standalone execution
    $useLogging = $false
}

# Check if bd is already installed
$bdPath = (Get-Command bd -ErrorAction SilentlyContinue).Source
if ($bdPath) {
    try {
        $version = & bd --version 2>&1 | Select-Object -First 1
        if ($useLogging) {
            Write-StepMessage "[Beads (bd)]" "[INFO] Existing installation detected: $version - updating to latest"
        }
        else {
            Write-Output "[Beads (bd)] [INFO] Existing installation detected: $version - updating to latest"
        }
    }
    catch {
        if (-not $useLogging) {
            Write-Output "[Beads (bd)] Installing..."
        }
    }
}
else {
    if (-not $useLogging) {
        Write-Output "[Beads (bd)] Installing..."
    }
}

# Download and execute the official installer
try {
    $installerUrl = "https://raw.githubusercontent.com/steveyegge/beads/main/install.ps1"
    $installerScript = Invoke-RestMethod -Uri $installerUrl

    # Execute the installer script (from official beads repository)
    Invoke-Expression $installerScript

    if ($useLogging) {
        Write-StepMessage "[Beads (bd)]" "[OK] Installation successful"
    }
    else {
        Write-Output "[Beads (bd)] [OK] Installation successful"
    }

    # Verify the installation
    $bdCommand = Get-Command bd -ErrorAction SilentlyContinue
    if ($bdCommand) {
        try {
            $bdVersion = & bd --version 2>&1 | Select-Object -First 1
            if ($useLogging) {
                Write-StepMessage "[Beads (bd)]" "Version: $bdVersion"
            }
            else {
                Write-Output "[Beads (bd)] Version: $bdVersion"
            }
        }
        catch {
            if ($useLogging) {
                Write-StepMessage "[Beads (bd)]" "[WARNING] Installed but version check failed"
            }
            else {
                Write-Output "[Beads (bd)] [WARNING] Installed but version check failed"
            }
        }
    }
    else {
        if ($useLogging) {
            Write-StepMessage "[Beads (bd)]" "[WARNING] Installed but not in PATH (restart shell required)"
        }
        else {
            Write-Output "[Beads (bd)] [WARNING] Installed but not in PATH (restart shell required)"
        }
    }
}
catch {
    if ($useLogging) {
        Write-StepMessage "[Beads (bd)]" "[ERROR] Installation failed: $_"
    }
    else {
        Write-Output "[Beads (bd)] [ERROR] Installation failed: $_"
    }
    exit 1
}
