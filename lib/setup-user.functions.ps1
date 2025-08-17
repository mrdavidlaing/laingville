# PowerShell user setup functions - Windows-native implementation
# Mirrors functionality from setup-user.functions.bash

# Import shared functions
. "$PSScriptRoot\shared.functions.ps1"

<#
.SYNOPSIS
    Gets Windows-specific config path for cross-platform compatibility
.PARAMETER RelativePath
    The relative path from the dotfiles directory
.PARAMETER Filename
    The filename to be placed in the target location
.DESCRIPTION
    Maps common Unix config paths to their Windows equivalents (e.g., .config/alacritty -> AppData)
.EXAMPLE
    Get-PlatformConfigPath ".config/alacritty/" "alacritty.toml"
#>
function Get-PlatformConfigPath {
    param(
        [string]$RelativePath,
        [string]$Filename
    )
    
    $fullPath = "${RelativePath}${Filename}"
    
    # Apply Windows-specific mappings
    switch -Wildcard ($fullPath) {
        ".config/alacritty/*" {
            # Extract the subpath after .config/alacritty/
            $subpath = $fullPath -replace '^\.config/alacritty/', ''
            $appdataPath = Join-Path $env:APPDATA "alacritty"
            
            # Create directory structure if it contains subdirectories
            $subdir = Split-Path $subpath -Parent
            if ($subdir -and $subdir -ne ".") {
                $targetDir = Join-Path $appdataPath $subdir
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            } else {
                New-Item -ItemType Directory -Path $appdataPath -Force | Out-Null
            }
            
            return Join-Path $appdataPath $subpath
        }
        default {
            # Default: use HOME directory with standard paths
            return Join-Path $env:USERPROFILE $fullPath
        }
    }
}

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
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    # Remove existing file/symlink
    if (Test-Path $Target) {
        Remove-Item $Target -Force
    }
    
    Write-LogInfo "Creating symlink: $Target -> $Source"
    
    # Create symlink using cmd mklink (requires Developer Mode)
    try {
        $result = & cmd.exe /c "mklink `"$Target`" `"$Source`"" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Linked: $Target -> $Source"
            return $true
        } else {
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

# File handler for create mode
function New-FileItem {
    param(
        [string]$Item,
        [string]$DestDir,
        [string]$RelativePath
    )
    
    $filename = Split-Path $Item -Leaf
    
    # Validate filename for security
    if (-not (Test-SafeFilename $filename)) {
        Write-Warning "Skipping unsafe filename: $filename"
        return $false
    }
    
    # Skip files that shouldn't be linked on Windows
    switch ($filename) {
        { $_ -in @('.bashrc', '.bashrc_git_learning', '.bash_profile', '.bash_logout') } {
            # Bash-specific files not needed on pure Windows
            return $true
        }
        { $_ -in @('dynamic-wallpaper.yml', 'dynamic-wallpaper') } {
            # Desktop environment files not needed on Windows
            return $true
        }
    }
    
    # Get platform-aware target path
    $target = Get-PlatformConfigPath $RelativePath $filename
    
    # Validate target path for security
    if (-not (Test-SafePath $target $env:USERPROFILE $true)) {
        Write-LogWarning "Skipping link outside allowed directories: $target"
        return $false
    }
    
    # Create the symlink
    return New-FileSymlink $target $Item
}

# Directory handler for create mode
function New-DirectoryItem {
    param(
        [string]$Item,
        [string]$DestDir,
        [string]$RelativePath
    )
    
    $dirname = Split-Path $Item -Leaf
    
    # Validate directory name
    if (-not (Test-SafeFilename $dirname)) {
        Write-Warning "Skipping unsafe directory name: $dirname"
        return $false
    }
    
    $targetDir = Join-Path $DestDir $dirname
    
    # Validate target directory
    if (-not (Test-SafePath $targetDir $env:USERPROFILE $true)) {
        Write-Warning "Skipping directory outside home: $targetDir"
        return $false
    }
    
    # Create target directory and recurse
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    return Invoke-CreateSymlinks $Item $targetDir "${RelativePath}${dirname}/" $false
}

# Show file item for dry-run mode
function Show-FileItem {
    param(
        [string]$Item,
        [string]$DestDir,
        [string]$RelativePath
    )
    
    $filename = Split-Path $Item -Leaf
    
    # Skip files that wouldn't be processed
    switch ($filename) {
        { $_ -in @('.bashrc', '.bashrc_git_learning', '.bash_profile', '.bash_logout') } {
            return $true
        }
        { $_ -in @('dynamic-wallpaper.yml', 'dynamic-wallpaper') } {
            return $true
        }
    }
    
    $target = Get-PlatformConfigPath $RelativePath $filename
    
    if (Test-Path $target) {
        Write-Host "* Would: update: $target -> $Item" -ForegroundColor Magenta
    } else {
        Write-Host "* Would: create: $target -> $Item" -ForegroundColor Cyan
    }
    
    return $true
}

# Show directory item for dry-run mode  
function Show-DirectoryItem {
    param(
        [string]$Item,
        [string]$DestDir,
        [string]$RelativePath
    )
    
    $dirname = Split-Path $Item -Leaf
    $targetDir = Join-Path $DestDir $dirname
    
    return Invoke-TraverseDotfiles "Show-FileItem" "Show-DirectoryItem" $Item $targetDir "${RelativePath}${dirname}/" $false
}

# Traverse dotfiles directory structure
function Invoke-TraverseDotfiles {
    param(
        [string]$FileHandler,
        [string]$DirHandler,
        [string]$SrcDir,
        [string]$DestDir,
        [string]$RelativePath,
        [bool]$FilterDotfiles = $true
    )
    
    if (-not (Test-Path $SrcDir)) {
        return $true
    }
    
    $success = $true
    $items = Get-ChildItem $SrcDir -Force
    
    foreach ($item in $items) {
        $basename = $item.Name
        
        # Filter for dotfiles at top level only
        if ($FilterDotfiles -and -not $basename.StartsWith('.')) {
            continue
        }
        
        # Skip special directories
        if ($basename -in @('.git', '.gitignore', '.DS_Store')) {
            continue
        }
        
        try {
            if ($item.PSIsContainer) {
                # Directory
                $result = & $DirHandler $item.FullName $DestDir $RelativePath
                if (-not $result) { $success = $false }
            } else {
                # File
                $result = & $FileHandler $item.FullName $DestDir $RelativePath
                if (-not $result) { $success = $false }
            }
        }
        catch {
            Write-LogError "Error processing $($item.Name): $_"
            $success = $false
        }
    }
    
    return $success
}

# Create symlinks with path validation
function Invoke-CreateSymlinks {
    param(
        [string]$SrcDir,
        [string]$DestDir,
        [string]$RelativePath,
        [bool]$FilterDotfiles = $true
    )
    
    return Invoke-TraverseDotfiles "New-FileItem" "New-DirectoryItem" $SrcDir $DestDir $RelativePath $FilterDotfiles
}

# Show symlinks for dry-run mode
function Show-Symlinks {
    param(
        [string]$SrcDir,
        [string]$DestDir,
        [string]$RelativePath,
        [bool]$FilterDotfiles = $true
    )
    
    if ($SrcDir -like "*\shared") {
        Write-Host "SHARED SYMLINKS:" -ForegroundColor White
    } else {
        Write-Host "USER SYMLINKS:" -ForegroundColor White
    }
    
    return Invoke-TraverseDotfiles "Show-FileItem" "Show-DirectoryItem" $SrcDir $DestDir $RelativePath $FilterDotfiles
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
        } else {
            Write-LogInfo "No symlinks.yaml found, skipping symlink creation"
        }
        return $true
    }
    
    $symlinks = Get-SymlinksFromYaml $symlinksFile "windows"
    
    if ($symlinks.Count -eq 0) {
        if ($DryRun) {
            Write-Host "SYMLINKS:" -ForegroundColor White
            Write-Host "* Would: skip (no Windows symlinks defined)" -ForegroundColor Gray
        } else {
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
            } else {
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
    Install-UserPackages "C:\repo\dotfiles\user" $false
#>
function Install-UserPackages {
    param(
        [string]$DotfilesDir,
        [bool]$DryRun = $false
    )
    
    $packagesFile = Join-Path $DotfilesDir "packages.yaml"
    
    if (-not (Test-Path $packagesFile)) {
        if ($DryRun) {
            Write-Host "PACKAGES:" -ForegroundColor White
            Write-Host "* Would: skip (no packages.yaml found)" -ForegroundColor Gray
        } else {
            Write-LogInfo "No packages.yaml found, skipping package installation"
        }
        return $true
    }
    
    $packages = Get-PackagesFromYaml $packagesFile "windows"
    
    if ($DryRun) {
        Write-Host "PACKAGES:" -ForegroundColor White
        if ($packages.winget.Count -gt 0) {
            foreach ($pkg in $packages.winget) {
                Write-Host "* Would: install winget package: $pkg" -ForegroundColor Cyan
            }
        }
        if ($packages.psmodule.Count -gt 0) {
            foreach ($module in $packages.psmodule) {
                Write-Host "* Would: install PowerShell module: $module" -ForegroundColor Cyan
            }
        }
        if ($packages.winget.Count -eq 0 -and $packages.psmodule.Count -eq 0) {
            Write-Host "* Would: skip (no Windows packages defined)" -ForegroundColor Gray
        }
        return $true
    }
    
    # Install winget packages
    if ($packages.winget.Count -gt 0) {
        Write-Step "Installing Windows Packages"
        $wingetResult = Install-WingetPackages $packages.winget
        if (-not $wingetResult) {
            return $false
        }
    }
    
    # Install PowerShell modules
    if ($packages.psmodule.Count -gt 0) {
        Write-Step "Installing PowerShell Modules"
        $moduleResult = Install-PowerShellModules $packages.psmodule
        if (-not $moduleResult) {
            return $false
        }
    }
    
    return $true
}

<#
.SYNOPSIS
    Provides instructions for running setup inside WSL if available
.PARAMETER DryRun
    Whether to show dry-run instructions or regular setup instructions
.DESCRIPTION
    Checks if WSL is available and provides the appropriate command to run the Linux setup
.EXAMPLE
    Invoke-WSLSetup $false
#>
function Invoke-WSLSetup {
    param(
        [bool]$DryRun = $false
    )
    
    # Simple check - if wsl.exe exists, show setup instructions
    if (-not (Get-Command "wsl.exe" -ErrorAction SilentlyContinue)) {
        Write-LogInfo "WSL not available, skipping Linux setup"
        return $true
    }
    
    # Convert Windows path to WSL path for the setup script
    $scriptRoot = Split-Path $PSScriptRoot -Parent
    $wslPath = $scriptRoot -replace '^([A-Z]):', '/mnt/$1' -replace '\\', '/' | ForEach-Object { $_.ToLower() }
    $setupScript = "$wslPath/bin/setup-user"
    
    if ($DryRun) {
        Write-Host "WSL SETUP:" -ForegroundColor White
        Write-LogInfo "To see what would be done in WSL, run:"
        Write-Host "  wsl.exe bash `"$setupScript`" --dry-run" -ForegroundColor Cyan
        return $true
    }
    
    Write-LogInfo "To complete setup in WSL, run:"
    Write-Host "  wsl.exe bash `"$setupScript`"" -ForegroundColor Cyan
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
    
    # Setup shared dotfiles (still use old approach as shared doesn't have symlinks.yaml)
    Write-Step "Shared Dotfiles"
    $sharedDir = Join-Path $scriptRoot "dotfiles\shared"
    
    if (Test-Path $sharedDir) {
        if ($DryRun) {
            Write-LogInfo "DRY RUN MODE - No changes will be made"
            $result = Show-Symlinks $sharedDir $env:USERPROFILE "" $true
        } else {
            Write-LogInfo "Setting up shared dotfiles..."
            $result = Invoke-CreateSymlinks $sharedDir $env:USERPROFILE "" $true
        }
        
        if (-not $result) {
            Write-LogError "Failed to setup shared dotfiles"
            return $false
        }
    }
    
    # Setup user-specific dotfiles using symlinks.yaml
    Write-Step "User-Specific Dotfiles"
    $result = Invoke-SymlinksFromConfig $dotfilesDir $DryRun
    
    if (-not $result) {
        Write-LogError "Failed to setup user dotfiles"
        return $false
    }
    
    # Install packages
    $packageResult = Install-UserPackages $dotfilesDir $DryRun
    if (-not $packageResult) {
        Write-LogWarning "Package installation encountered issues"
    }
    
    # Setup WSL environment
    Write-Step "WSL Setup"
    $wslResult = Invoke-WSLSetup $DryRun
    if (-not $wslResult) {
        Write-LogWarning "WSL setup encountered issues"
    }
    
    # Success
    if ($DryRun) {
        Write-LogSuccess "Dry run completed successfully"
    } else {
        Write-LogSuccess "User setup completed successfully"
    }
    
    return $true
}