[CmdletBinding()]
param(
    [switch]$DryRun
)

$logPrefix = '[Claude Code]'
$InformationPreference = 'Continue'

# Check if claude.exe is already available in PATH
$claudeCommand = Get-Command claude.exe -ErrorAction SilentlyContinue
if ($claudeCommand) {
    Write-Information "$logPrefix Claude Code CLI is already installed at: $($claudeCommand.Source)" -Tags 'Success'
    return
}

if ($DryRun) {
    Write-Information "$logPrefix [DRY RUN] Would install native Claude Code via https://claude.ai/install.ps1" -Tags 'DryRun'
    return
}

Write-Information "$logPrefix Installing native Windows binary..." -Tags 'Info'

try {
    # Download and execute the official installer
    $installScriptContent = Invoke-RestMethod -Uri 'https://claude.ai/install.ps1'
    if (-not $installScriptContent) {
        throw "Installer script returned no content"
    }

    $installScript = [ScriptBlock]::Create($installScriptContent)
    & $installScript | Out-Null
    Write-Information "$logPrefix [OK] Native installer completed" -Tags 'Success'

    # Verify installation succeeded
    $claudeCommand = Get-Command claude.exe -ErrorAction SilentlyContinue
    if (-not $claudeCommand) {
        throw "Installation completed but 'claude.exe' command not found on PATH"
    }

    Write-Information "$logPrefix Installed location: $($claudeCommand.Source)" -Tags 'Info'

    try {
        $version = & $claudeCommand.Source --version
        if ($version) {
            Write-Information "$logPrefix Installed version: $version" -Tags 'Success'
        }
    }
    catch {
        Write-Warning "$logPrefix Unable to determine installed version: $_"
    }
}
catch {
    Write-Error "$logPrefix Installation failed: $_"
    exit 1
}
