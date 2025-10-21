[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()

# PowerShell user setup functions - Windows-native implementation
# Mirrors functionality from setup-user.functions.bash

# Import shared functions
. "$PSScriptRoot\shared.functions.ps1"

<#
.SYNOPSIS
    Creates a Windows symbolic link between target and source
.PARAMETER Target
    The path where the symlink will be created
.PARAMETER Source
    The path to the file/directory to link to
.DESCRIPTION
    Creates a symbolic link using cmd mklink, requires Developer Mode to be enabled
.EXAMPLE
    New-FileSymlink "C:\Users\user\.bashrc" "C:\repo\dotfiles\.bashrc"
#>
function New-FileSymlink {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Target,
        [string]$Source
    )

    if (-not $Target -or -not $Source) {
        Write-LogError "Target and Source paths are required"
        return $false
    }

    # Ensure parent directory exists
    $targetDir = Split-Path $Target -Parent
    if (-not (Test-Path $targetDir)) {
        if ($PSCmdlet.ShouldProcess($targetDir, "Create directory")) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
    }

    # Remove existing file/symlink
    if (Test-Path $Target) {
        if ($PSCmdlet.ShouldProcess($Target, "Remove existing file")) {
            Remove-Item $Target -Force
        }
    }

    Write-LogInfo "Creating symlink: $Target -> $Source"

    # Create symlink using cmd mklink (requires Developer Mode)
    if ($PSCmdlet.ShouldProcess($Target, "Create symlink to $Source")) {
        try {
            # Check if source is a directory and use /D flag for directory symlinks
            $isDirectory = Test-Path -Path $Source -PathType Container
            $mklinkCmd = if ($isDirectory) {
                "mklink /D `"$Target`" `"$Source`""
            }
            else {
                "mklink `"$Target`" `"$Source`""
            }

            $result = & cmd.exe /c $mklinkCmd 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "Linked: $Target -> $Source"
                return $true
            }
            else {
                Write-LogError "Failed to create symlink: $Target -> $Source"
                Write-LogError "mklink error: $result"
                Write-LogError "Ensure Windows prerequisites are met:"
                Write-LogError "  1. Run setup.ps1 to enable Developer Mode"
                Write-LogError "  2. Restart this script after prerequisites are satisfied"
                return $false
            }
        }
        catch {
            Write-LogError "Exception creating symlink: $_"
            return $false
        }
    }
    else {
        return $true
    }
}

<#
.SYNOPSIS
    Creates symlinks based on symlinks.yaml configuration
.PARAMETER DotfilesDir
    Path to the dotfiles directory containing symlinks.yaml
.PARAMETER DryRun
    Whether to show what would be done instead of making changes
.DESCRIPTION
    Reads symlinks.yaml and creates the specified symbolic links for Windows
.EXAMPLE
    Invoke-SymlinksFromConfig "C:\repo\dotfiles\user" $false
#>
function Invoke-SymlinksFromConfig {
    param(
        [string]$DotfilesDir,
        [bool]$DryRun = $false
    )

    $symlinksFile = Join-Path $DotfilesDir "symlinks.yaml"

    if (-not (Test-Path $symlinksFile)) {
        if ($DryRun) {
            Write-Host "SYMLINKS:" -ForegroundColor White
            Write-Host "* Would: skip (no symlinks.yaml found)" -ForegroundColor Gray
        }
        else {
            Write-LogInfo "No symlinks.yaml found, skipping symlink creation"
        }
        return $true
    }

    $symlinks = Get-SymlinksFromYaml $symlinksFile "windows"

    if ($symlinks.Count -eq 0) {
        if ($DryRun) {
            Write-Host "SYMLINKS:" -ForegroundColor White
            Write-Host "* Would: skip (no Windows symlinks defined)" -ForegroundColor Gray
        }
        else {
            Write-LogInfo "No Windows symlinks defined, skipping symlink creation"
        }
        return $true
    }

    if ($DryRun) {
        Write-Host "SYMLINKS:" -ForegroundColor White
        foreach ($symlink in $symlinks) {
            $sourcePath = Join-Path $DotfilesDir $symlink.source
            $targetPath = Expand-WindowsPath $symlink.target

            if (Test-Path $targetPath) {
                Write-Host "* Would: update: $targetPath -> $sourcePath" -ForegroundColor Magenta
            }
            else {
                Write-Host "* Would: create: $targetPath -> $sourcePath" -ForegroundColor Cyan
            }
        }
        return $true
    }

    Write-LogInfo "Creating symlinks from symlinks.yaml..."
    $success = $true

    foreach ($symlink in $symlinks) {
        $sourcePath = Join-Path $DotfilesDir $symlink.source
        $targetPath = Expand-WindowsPath $symlink.target

        # Validate paths are not empty
        if (-not $sourcePath -or -not $targetPath) {
            Write-LogWarning "Skipping symlink with empty path - source: '$sourcePath', target: '$targetPath'"
            continue
        }

        # Validate source exists
        if (-not (Test-Path $sourcePath)) {
            Write-LogWarning "Source file not found, skipping: $sourcePath"
            continue
        }

        # Validate target path for security
        if (-not (Test-SafePath $targetPath $env:USERPROFILE $true)) {
            Write-LogWarning "Skipping link outside allowed directories: $targetPath"
            continue
        }

        # Create the symlink
        $result = New-FileSymlink $targetPath $sourcePath
        if (-not $result) {
            $success = $false
        }
    }

    return $success
}

<#
.SYNOPSIS
    Processes and installs packages for the current user
.PARAMETER DotfilesDir
    Path to the dotfiles directory containing packages.yaml
.PARAMETER DryRun
    Whether to show what would be done instead of installing packages
.DESCRIPTION
    Reads packages.yaml and installs Windows packages using winget
.EXAMPLE
    Install-UserPackage "C:\repo\dotfiles\user" $false
#>
function Invoke-CustomWindowsScript {
    param(
        [string]$DotfilesDir,
        [string[]]$Scripts,
        [bool]$DryRun = $false
    )

    if (-not $Scripts -or $Scripts.Count -eq 0) {
        return $true
    }

    $repoRoot = Split-Path $DotfilesDir -Parent
    $sharedScriptsDir = Join-Path $repoRoot "dotfiles\shared\scripts"
    $userScriptsDir = Join-Path $DotfilesDir "scripts"

    $success = $true

    foreach ($scriptName in $Scripts) {
        if (-not $scriptName) {
            continue
        }

        $scriptName = $scriptName.Trim()
        if (-not $scriptName) {
            continue
        }

        $scriptFile = if ($scriptName.EndsWith('.ps1', [System.StringComparison]::OrdinalIgnoreCase)) {

            $scriptName
        }
        else {
            "$scriptName.ps1"
        }

        $safeName = Split-Path $scriptFile -Leaf
        if (-not (Test-SafeFilename $safeName)) {
            Write-LogWarning "Skipping custom script with unsafe name: $scriptName"
            $success = $false
            continue
        }

        $candidatePaths = @()
        if (Test-Path $sharedScriptsDir) {
            $candidatePaths += Join-Path $sharedScriptsDir $scriptFile
        }
        if (Test-Path $userScriptsDir) {
            $candidatePaths += Join-Path $userScriptsDir $scriptFile
        }

        $scriptPath = $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $scriptPath -and (Test-Path $sharedScriptsDir)) {
            $scriptPath = Get-ChildItem -Path $sharedScriptsDir -Filter $scriptFile -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1 | Select-Object -ExpandProperty FullName
        }

        if (-not $scriptPath) {

            if ($DryRun) {
                Write-Host "* Would: run custom script (missing): $scriptName" -ForegroundColor Yellow
            }
            else {
                Write-LogWarning "Custom script not found: $scriptName"
                $success = $false
            }
            continue
        }

        if ($DryRun) {
            Write-Host "* Would: run custom script: $scriptName" -ForegroundColor Cyan
            continue
        }

        if (-not (Test-SafePath $scriptPath $repoRoot $false)) {
            Write-LogWarning "Custom script outside repository scope: $scriptName"
            $success = $false
            continue
        }

        Write-LogInfo "Running custom script: $scriptName"
        try {
            & $scriptPath
            Write-LogSuccess "Custom script $scriptName completed successfully"
        }
        catch {
            Write-LogWarning "Custom script $scriptName failed: $_"
            $success = $false
        }
    }

    return $success
}

function Install-UserPackage {
    param(
        [string]$DotfilesDir,
        [bool]$DryRun = $false
    )

    $packagesFile = Join-Path $DotfilesDir "packages.yaml"

    if (-not (Test-Path $packagesFile)) {
        if ($DryRun) {
            Write-Host "PACKAGES:" -ForegroundColor White
            Write-Host "* Would: skip (no packages.yaml found)" -ForegroundColor Gray
        }
        else {
            Write-LogInfo "No packages.yaml found, skipping package installation"
        }
        return $true
    }

    $packages = Get-PackagesFromYaml $packagesFile

    if ($DryRun) {
        Write-Host "PACKAGES:" -ForegroundColor White
        # Show cleanup operations
        if ($packages.winget_cleanup.Count -gt 0) {
            foreach ($pkg in $packages.winget_cleanup) {
                Write-Host "* Would: remove winget package: $pkg" -ForegroundColor Magenta
            }
        }
        if ($packages.scoop_cleanup.Count -gt 0) {
            foreach ($pkg in $packages.scoop_cleanup) {
                Write-Host "* Would: remove scoop package: $pkg" -ForegroundColor Magenta
            }
        }
        if ($packages.psmodule_cleanup.Count -gt 0) {
            foreach ($module in $packages.psmodule_cleanup) {
                Write-Host "* Would: remove PowerShell module: $module" -ForegroundColor Magenta
            }
        }
        # Show install operations
        if ($packages.winget.Count -gt 0) {
            foreach ($pkg in $packages.winget) {
                Write-Host "* Would: install winget package: $pkg" -ForegroundColor Cyan
            }
        }
        if ($packages.scoop.Count -gt 0) {
            foreach ($pkg in $packages.scoop) {
                Write-Host "* Would: install scoop package: $pkg" -ForegroundColor Cyan
            }
        }
        if ($packages.psmodule.Count -gt 0) {
            foreach ($module in $packages.psmodule) {
                Write-Host "* Would: install PowerShell module: $module" -ForegroundColor Cyan
            }
        }
        if ($packages.custom.Count -gt 0) {
            foreach ($script in $packages.custom) {
                Write-Host "* Would: run custom script: $script" -ForegroundColor Cyan
            }
        }
        if ($packages.winget.Count -eq 0 -and $packages.scoop.Count -eq 0 -and $packages.psmodule.Count -eq 0 -and
            $packages.winget_cleanup.Count -eq 0 -and $packages.scoop_cleanup.Count -eq 0 -and $packages.psmodule_cleanup.Count -eq 0 -and
            $packages.custom.Count -eq 0) {
            Write-Host "* Would: skip (no Windows packages defined)" -ForegroundColor Gray
        }
        return $true
    }

    # Remove cleanup packages first
    if ($packages.winget_cleanup.Count -gt 0) {
        Write-Step "Removing Windows Packages"
        $wingetCleanupResult = Remove-WingetPackage $packages.winget_cleanup
        if (-not $wingetCleanupResult) {
            return $false
        }
    }

    if ($packages.scoop_cleanup.Count -gt 0) {
        Write-Step "Removing Scoop Packages"
        $scoopCleanupResult = Remove-ScoopPackage $packages.scoop_cleanup
        if (-not $scoopCleanupResult) {
            return $false
        }
    }

    if ($packages.psmodule_cleanup.Count -gt 0) {
        Write-Step "Removing PowerShell Modules"
        $moduleCleanupResult = Remove-PowerShellModule $packages.psmodule_cleanup
        if (-not $moduleCleanupResult) {
            return $false
        }
    }

    # Install winget packages
    if ($packages.winget.Count -gt 0) {
        Write-Step "Installing Windows Packages"
        $wingetResult = Install-WingetPackage $packages.winget
        if (-not $wingetResult) {
            return $false
        }
    }

    # Install scoop packages
    if ($packages.scoop.Count -gt 0) {
        Write-Step "Installing Scoop Packages"
        $scoopResult = Install-ScoopPackage $packages.scoop
        if (-not $scoopResult) {
            return $false
        }
    }

    # Install PowerShell modules
    if ($packages.psmodule.Count -gt 0) {
        Write-Step "Installing PowerShell Modules"
        $moduleResult = Install-PowerShellModule $packages.psmodule
        if (-not $moduleResult) {
            return $false
        }
    }

    if ($packages.custom.Count -gt 0) {
        Write-Step "Running Custom Scripts"
        $customResult = Invoke-CustomWindowsScript -DotfilesDir $DotfilesDir -Scripts $packages.custom -DryRun:$DryRun
        if (-not $customResult) {
            return $false
        }
    }

    return $true
}

# Test if Developer Mode is enabled by attempting to create a test symlink
function Test-DeveloperModeEnabled {
    $testDir = Join-Path $env:TEMP "symlink_test_$(Get-Random)"
    $testFile = Join-Path $testDir "test.txt"
    $testLink = Join-Path $testDir "test_link.txt"

    try {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        "test content" | Out-File -FilePath $testFile -Encoding UTF8

        # Try to create a symbolic link
        $result = & cmd.exe /c "mklink `"$testLink`" `"$testFile`"" 2>&1
        $success = ($LASTEXITCODE -eq 0) -and (Test-Path $testLink)

        if (-not $success -and $result) {
            Write-LogError "Symlink test failed: $result"
        }

        # Clean up
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue

        return $success
    }
    catch {
        # Clean up on error
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
}

<#
.SYNOPSIS
    Main user setup function that orchestrates the entire Windows dotfiles setup
.PARAMETER DryRun
    Whether to show what would be done instead of making actual changes
.DESCRIPTION
    Handles the complete user setup process including:
    - Checking prerequisites (Developer Mode)
    - Setting up shared and user-specific dotfiles
    - Installing packages
    - Providing WSL setup instructions
.EXAMPLE
    Invoke-UserSetup $false
#>
function Invoke-UserSetup {
    param(
        [bool]$DryRun = $false
    )

    # Check Developer Mode upfront (unless in dry-run mode)
    if (-not $DryRun) {
        Write-Step "Checking Windows Prerequisites"
        if (-not (Test-DeveloperModeEnabled)) {
            Write-LogError "Developer Mode is not enabled or symlink creation failed"
            Write-LogError ""
            Write-LogError "To enable Developer Mode:"
            Write-LogError "1. Open Windows Settings (Win + I)"
            Write-LogError "2. Go to Update & Security > For developers"
            Write-LogError "3. Turn on 'Developer Mode'"
            Write-LogError "4. Restart this script after enabling Developer Mode"
            Write-LogError ""
            Write-LogError "Alternatively, run setup.ps1 which can guide you through prerequisites"
            return $false
        }
        Write-LogSuccess "Developer Mode is enabled - symlink creation is supported"
    }

    $currentUser = Get-CurrentUser
    Write-LogInfo "Using dotfiles for user: $currentUser"

    # Determine dotfiles directory
    $scriptRoot = Split-Path $PSScriptRoot -Parent
    $dotfilesDir = Join-Path $scriptRoot "dotfiles\$currentUser"

    Write-Step "User Setup for $currentUser"
    Write-LogInfo "Using dotfiles from: $dotfilesDir"

    # Validation
    Write-Step "Validation"
    if (-not (Test-Path $dotfilesDir)) {
        Write-LogError "Dotfiles directory not found: $dotfilesDir"
        return $false
    }
    Write-LogSuccess "Dotfiles directory found"

    # Note: Shared dotfiles directory contains only scripts and .local/bin helpers
    # No actual dotfiles to symlink, so we skip this step
    Write-Step "Shared Dotfiles"
    Write-LogInfo "Shared directory contains no dotfiles (only scripts), skipping symlink creation"

    # Setup user-specific dotfiles using symlinks.yaml
    Write-Step "User-Specific Dotfiles"
    $result = Invoke-SymlinksFromConfig $dotfilesDir $DryRun

    if (-not $result) {
        Write-LogError "Failed to setup user dotfiles"
        return $false
    }

    # Install packages
    $packageResult = Install-UserPackage $dotfilesDir $DryRun
    if (-not $packageResult) {
        Write-LogWarning "Package installation encountered issues"
    }

    # Success - WSL setup instructions will be shown by setup.ps1
    if ($DryRun) {
        Write-LogSuccess "Windows dry run completed successfully"
    }
    else {
        Write-LogSuccess "Windows setup completed successfully"
    }

    return $true
}
