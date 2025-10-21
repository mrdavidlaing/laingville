# Claude Code plugin management functions for PowerShell
# Provides automated plugin installation and marketplace management

<#
.SYNOPSIS
    Extracts Claude Code plugins from packages.yaml content
.PARAMETER YamlContent
    The raw YAML content to parse
.DESCRIPTION
    Parses YAML content and extracts plugins from the claudecode.plugins section
    Returns array of plugin strings in format: plugin@marketplace
#>
function Get-ClaudeCodePluginsFromYaml {
    param([string]$YamlContent)

    if (-not $YamlContent) {
        return @()
    }

    $plugins = @()
    $inClaudeCode = $false
    $inPlugins = $false

    foreach ($line in $YamlContent -split "\r?\n") {
        # Remove leading whitespace for easier parsing
        $trimmedLine = $line.TrimStart()

        # Check for claudecode section
        if ($trimmedLine -eq "claudecode:") {
            $inClaudeCode = $true
            continue
        }

        # Check for plugins subsection (must come before top-level exit check)
        if ($inClaudeCode -and $trimmedLine -eq "plugins:") {
            $inPlugins = $true
            continue
        }

        # Exit claudecode section if we hit another top-level key (no leading whitespace in original line)
        if ($inClaudeCode -and ($line -eq $trimmedLine) -and ($trimmedLine -match "^[a-z].*:$")) {
            $inClaudeCode = $false
            $inPlugins = $false
            continue
        }

        # Exit plugins subsection if we hit another subsection within claudecode
        if ($inPlugins -and ($line -ne $trimmedLine) -and ($trimmedLine -match "^[a-z].*:$")) {
            $inPlugins = $false
            continue
        }

        # Extract plugin entries (lines starting with -)
        if ($inPlugins -and ($trimmedLine -match "^- (.+)$")) {
            $plugin = $Matches[1].Trim()
            $plugins += $plugin
        }
    }

    return , $plugins
}

<#
.SYNOPSIS
    Extracts marketplace from plugin@marketplace format
.PARAMETER Plugin
    The plugin string in format: plugin-name@owner/marketplace-repo
.DESCRIPTION
    Parses plugin string and extracts the marketplace portion
    Returns marketplace string (e.g., "owner/repo") or $null if format invalid
#>
function Get-MarketplaceFromPlugin {
    param([string]$Plugin)

    if (-not $Plugin) {
        return $null
    }

    # Check if plugin contains @
    if ($Plugin -notmatch "@") {
        return $null
    }

    # Extract everything after @
    $marketplace = $Plugin -replace "^[^@]*@", ""

    if (-not $marketplace) {
        return $null
    }

    return $marketplace
}

<#
.SYNOPSIS
    Ensures marketplace is added to Claude Code
.PARAMETER Marketplace
    The marketplace in format: owner/repo
.PARAMETER DryRun
    If true, only show what would be done without executing
.DESCRIPTION
    Idempotently adds marketplace to Claude Code CLI
    Returns $true on success, $false on failure
#>
function Add-ClaudeCodeMarketplace {
    param(
        [string]$Marketplace,
        [bool]$DryRun = $false
    )

    if (-not $Marketplace) {
        Write-LogError "Marketplace name is required"
        return $false
    }

    # Security validation - marketplace should be owner/repo format
    # Allow alphanumeric, hyphens, underscores, and forward slash
    if ($Marketplace -notmatch "^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$") {
        Write-LogError "Invalid marketplace name: $Marketplace"
        return $false
    }

    if ($DryRun) {
        Write-LogInfo "[DRY RUN] Would add marketplace: $Marketplace"
        return $true
    }

    Write-LogInfo "Adding marketplace: $Marketplace"

    try {
        $null = & claude.exe plugin marketplace add $Marketplace 2>&1
        Write-LogSuccess "Marketplace added: $Marketplace"
        return $true
    }
    catch {
        Write-LogWarning "Failed to add marketplace: $Marketplace (may already exist)"
        return $true  # Not a fatal error - marketplace might already exist
    }
}

<#
.SYNOPSIS
    Installs or updates a Claude Code plugin
.PARAMETER Plugin
    The plugin in format: plugin-name@owner/marketplace-repo
.PARAMETER DryRun
    If true, only show what would be done without executing
.DESCRIPTION
    Installs or updates a plugin using Claude Code CLI
    Returns $true on success, $false on failure
#>
function Install-ClaudeCodePlugin {
    param(
        [string]$Plugin,
        [bool]$DryRun = $false
    )

    if (-not $Plugin) {
        Write-LogError "Plugin name is required"
        return $false
    }

    # Validate plugin format (must contain @)
    if ($Plugin -notmatch "@") {
        Write-LogError "Invalid plugin format: $Plugin (expected plugin@marketplace)"
        return $false
    }

    # Security validation - extract parts and validate
    $pluginName = $Plugin -replace "@.*", ""
    $marketplace = Get-MarketplaceFromPlugin $Plugin

    if (-not $pluginName -or -not $marketplace) {
        Write-LogError "Invalid plugin format: $Plugin"
        return $false
    }

    # Validate characters (alphanumeric, hyphens, underscores, @, /)
    if ($Plugin -notmatch "^[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$") {
        Write-LogError "Invalid plugin name: $Plugin"
        return $false
    }

    if ($DryRun) {
        Write-LogInfo "[DRY RUN] Would install plugin: $Plugin"
        return $true
    }

    Write-LogInfo "Installing plugin: $Plugin"

    try {
        $null = & claude.exe plugin install $Plugin 2>&1
        Write-LogSuccess "Plugin installed: $Plugin"
        return $true
    }
    catch {
        Write-LogError "Failed to install plugin: $Plugin"
        return $false
    }
}

<#
.SYNOPSIS
    Main handler for Claude Code plugin management
.PARAMETER DryRun
    If true, only show what would be done without executing
.DESCRIPTION
    Processes all plugins from packages.yaml
    Automatically manages marketplaces and installs/updates plugins
    Returns $true on success, $false on failure
#>
function Invoke-ClaudeCodePluginSetup {
    param([bool]$DryRun = $false)

    # Check if packages.yaml exists
    $packagesFile = Join-Path $env:DOTFILES_DIR "packages.yaml"
    if (-not (Test-Path $packagesFile)) {
        Write-LogInfo "No packages.yaml found, skipping Claude Code plugin setup"
        return $true
    }

    # Extract plugins from YAML
    $yamlContent = Get-Content $packagesFile -Raw
    $plugins = Get-ClaudeCodePluginsFromYaml $yamlContent

    if ($plugins.Count -eq 0) {
        Write-LogInfo "No Claude Code plugins configured"
        return $true
    }

    # Track seen marketplaces (using hashtable for deduplication)
    $seenMarketplaces = @{}

    # Process each plugin
    foreach ($plugin in $plugins) {
        if (-not $plugin) {
            continue
        }

        # Extract marketplace
        $marketplace = Get-MarketplaceFromPlugin $plugin

        if (-not $marketplace) {
            Write-LogWarning "Invalid plugin format: $plugin (skipping)"
            continue
        }

        # Add marketplace if not seen before
        if (-not $seenMarketplaces.ContainsKey($marketplace)) {
            $null = Add-ClaudeCodeMarketplace -Marketplace $marketplace -DryRun $DryRun
            $seenMarketplaces[$marketplace] = $true
        }

        # Install/update plugin
        if (-not (Install-ClaudeCodePlugin -Plugin $plugin -DryRun $DryRun)) {
            Write-LogWarning "Continuing with remaining plugins..."
        }
    }

    Write-LogSuccess "Claude Code plugin setup complete"
    return $true
}
