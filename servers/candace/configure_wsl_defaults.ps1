# Configure WSL defaults for candace server
# Sets WSL version 2 as default and archlinux as default distribution

function Set-WSLDefault {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Information "Configuring WSL defaults..." -InformationAction Continue

    try {
        # Set default WSL version to 2
        if ($PSCmdlet.ShouldProcess("WSL", "Set default WSL version to 2")) {
            Write-Information "Setting default WSL version to 2..." -InformationAction Continue
            wsl.exe --set-default-version 2
        }

        # Set default distribution to archlinux
        if ($PSCmdlet.ShouldProcess("WSL", "Set default distribution to archlinux")) {
            Write-Information "Setting default distribution to archlinux..." -InformationAction Continue
            wsl.exe --set-default archlinux
        }

        Write-Information "WSL defaults configured successfully!" -InformationAction Continue
    }
    catch {
        Write-Error "Failed to configure WSL defaults: $_"
        exit 1
    }
}

# Run the configuration
Set-WSLDefault
