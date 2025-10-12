[CmdletBinding()]
param(
    [switch]$DryRun
)

$logPrefix = '[Claude Code]'

if ($DryRun) {
    Write-Host "$logPrefix [DRY RUN] Would install native Claude Code via https://claude.ai/install.ps1" -ForegroundColor Cyan
    $message = "{0} [DRY RUN] Would execute: & ([scriptblock]::Create((Invoke-RestMethod 'https://claude.ai/install.ps1'))))" -f $logPrefix
    Write-Host $message -ForegroundColor Cyan
    return
}

Write-Host "$logPrefix Installing native Windows binary..."

$pauseAction = {
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    try {
        [void][System.Console]::ReadKey($true)
    }
    catch {
        try {
            cmd.exe /c "pause" | Out-Null
        }
        catch {
        }
    }
}

try {
    $installScriptContent = Invoke-RestMethod -Uri 'https://claude.ai/install.ps1'
    if (-not $installScriptContent) {
        throw "Installer script returned no content"
    }

    $installScript = [ScriptBlock]::Create($installScriptContent)
    & $installScript | Out-Null
    Write-Host "$logPrefix [OK] Native installer completed" -ForegroundColor Green

    # Verify installation
    $claudeCommand = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCommand) {
        try {
            $version = & claude --version
            Write-Host "$logPrefix Installed version: $version" -ForegroundColor Green
        }
        catch {
            Write-Warning "$logPrefix Unable to determine installed version: $_"
        }
    }
    else {
        Write-Warning "$logPrefix 'claude' command not found on PATH after installation"
    }
}
catch {
    Write-Error "$logPrefix Installation failed: $_"
    throw
}
finally {
    & $pauseAction
}

