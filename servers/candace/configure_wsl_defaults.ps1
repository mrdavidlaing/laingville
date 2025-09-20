# Configure WSL defaults for candace server
# Sets WSL version 2 as default and archlinux as default distribution

function Configure-WSLDefaults {
    Write-Host "Configuring WSL defaults..." -ForegroundColor Green

    try {
        # Set default WSL version to 2
        Write-Host "Setting default WSL version to 2..." -ForegroundColor Yellow
        wsl.exe --set-default-version 2

        # Set default distribution to archlinux
        Write-Host "Setting default distribution to archlinux..." -ForegroundColor Yellow
        wsl.exe --set-default archlinux

        Write-Host "WSL defaults configured successfully!" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to configure WSL defaults: $_"
        exit 1
    }
}

# Run the configuration
Configure-WSLDefaults