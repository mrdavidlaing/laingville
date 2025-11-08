#!/usr/bin/env pwsh

# Tailscale Configuration Script for Windows
# Verifies tailscaled service and optionally authenticates with Tailscale

[CmdletBinding()]
param(
    [string]$DryRun = "false"
)

$ErrorActionPreference = "Stop"

if ($DryRun -eq "true") {
    Write-Host "[Tailscale] [DRY RUN] Would verify tailscaled service is running"
    if ($env:TS_AUTHKEY) {
        Write-Host "[Tailscale] [DRY RUN] Would authenticate with TS_AUTHKEY and enable --ssh --accept-routes"
    }
    else {
        Write-Host "[Tailscale] [DRY RUN] Would print authentication instructions"
    }
    exit 0
}

Write-Host -NoNewline "[Tailscale] "

# Check if tailscale is installed
$tailscalePath = Get-Command tailscale -ErrorAction SilentlyContinue
if (-not $tailscalePath) {
    Write-Host "[ERROR] Tailscale not found. Please install it first."
    exit 1
}

# Check if tailscaled service is running
$service = Get-Service -Name "Tailscale" -ErrorAction SilentlyContinue
if (-not $service) {
    Write-Host "[WARNING] Tailscaled service not found"
    Write-Host "The service should be installed automatically by the Tailscale installer."
    Write-Host "Try reinstalling Tailscale or running the installer again."
    exit 1
}

if ($service.Status -ne "Running") {
    Write-Host "Starting Tailscale service..."
    try {
        Start-Service -Name "Tailscale"
        Write-Host "[Tailscale] Service started"
    }
    catch {
        Write-Host "[WARNING] Failed to start Tailscale service: $_"
        Write-Host "You may need to start it manually from Services or the Tailscale tray icon."
    }
}
else {
    Write-Host "Service already running"
}

# Check if already authenticated
try {
    $status = tailscale status 2>&1
    if ($LASTEXITCODE -eq 0 -and $status -notmatch "Logged out") {
        Write-Host "[OK] Tailscale already authenticated"
        Write-Host ""
        tailscale status
        exit 0
    }
}
catch {
    # Continue to authentication
}

# Get hostname for Tailscale (append -tailnet suffix to distinguish from local network)
$tsHostname = "$env:COMPUTERNAME-tailnet"

# Authenticate with Tailscale
if ($env:TS_AUTHKEY) {
    Write-Host "Authenticating with auth key (hostname: $tsHostname)..."
    try {
        tailscale up --authkey="$env:TS_AUTHKEY" --hostname="$tsHostname" --ssh --accept-routes
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[Tailscale] [OK] Authentication successful"
            Write-Host ""
            tailscale status
        }
        else {
            Write-Host "[Tailscale] [ERROR] Authentication failed"
            exit 1
        }
    }
    catch {
        Write-Host "[Tailscale] [ERROR] Authentication failed: $_"
        exit 1
    }
}
else {
    Write-Host "[OK] Service configured"
    Write-Host ""
    Write-Host "To authenticate Tailscale, run:"
    Write-Host "  tailscale up --hostname=`"$tsHostname`" --ssh --accept-routes"
    Write-Host ""
    Write-Host "This will:"
    Write-Host "  - Register as '$tsHostname' on your Tailscale network"
    Write-Host "  - Open your browser to authenticate"
    Write-Host "  - Enable Tailscale SSH for remote access"
    Write-Host "  - Accept subnet routes from other devices"
    Write-Host ""
    Write-Host "Optional: Set `$env:TS_AUTHKEY environment variable for automated authentication"
    Write-Host "  Get auth key from: https://login.tailscale.com/admin/settings/keys"
}
