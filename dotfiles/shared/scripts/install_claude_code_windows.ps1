[CmdletBinding()]
param(
    [switch]$DryRun
)

$logPrefix = '[Claude Code]'

# Check if claude.exe is already available in PATH
$claudeCommand = Get-Command claude.exe -ErrorAction SilentlyContinue
if ($claudeCommand) {
    Write-Host "$logPrefix Claude Code CLI is already installed at: $($claudeCommand.Source)" -ForegroundColor Green
    return
}

if ($DryRun) {
    Write-Host "$logPrefix [DRY RUN] Would install native Claude Code via https://claude.ai/install.ps1" -ForegroundColor Cyan
    return
}

Write-Host "$logPrefix Installing native Windows binary..."

try {
    # Download and execute the official installer
    $installScriptContent = Invoke-RestMethod -Uri 'https://claude.ai/install.ps1'
    if (-not $installScriptContent) {
        throw "Installer script returned no content"
    }

    $installScript = [ScriptBlock]::Create($installScriptContent)
    & $installScript | Out-Null
    Write-Host "$logPrefix [OK] Native installer completed" -ForegroundColor Green

    # Verify installation succeeded
    $claudeCommand = Get-Command claude.exe -ErrorAction SilentlyContinue
    if (-not $claudeCommand) {
        throw "Installation completed but 'claude.exe' command not found on PATH"
    }

    Write-Host "$logPrefix Installed location: $($claudeCommand.Source)" -ForegroundColor Gray

    try {
        $version = & $claudeCommand.Source --version
        if ($version) {
            Write-Host "$logPrefix Installed version: $version" -ForegroundColor Green
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

