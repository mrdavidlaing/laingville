# PowerShell profile for mrdavidlaing
# This file is symlinked to the appropriate PowerShell profile location

# Add user's local bin to PATH for PowerShell sessions
$localBin = Join-Path $env:USERPROFILE ".local\bin"
if (Test-Path $localBin) {
    $env:PATH = "$localBin;$env:PATH"
}

# Set default editor for PowerShell
$env:EDITOR = "nvim"

# Load 1Password environment secrets if available
$secretsFile = Join-Path $env:USERPROFILE ".config\env.secrets.local"
if (Test-Path $secretsFile) {
    . $secretsFile
}

# Enhanced directory listings (prefer eza when available)
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ls { eza --icons --group-directories-first }
    function ll { eza -la --icons --group-directories-first }
    function la { eza -a --icons }
    function lzg { eza -la --icons --git }
    function lt { eza --tree --icons --level=2 }
    function lt3 { eza --tree --icons --level=3 }
    function lm { eza -la --icons --sort=modified }
    function lsize { eza -la --icons --sort=size }
}
else {
    Write-Warning "eza not found; enhanced ls functions disabled. Install it with 'scoop install eza'."
}

# Aliases for development workflows
Set-Alias vim nvim
Set-Alias vi nvim
Set-Alias grep "grep --color=auto"
# Override built-in cd alias
Remove-Item alias:cd -Force -ErrorAction SilentlyContinue
Set-Alias cd z

# Ensure Windows tree.com is available in PowerShell
if (-not (Get-Command tree -ErrorAction SilentlyContinue) -and (Test-Path "C:\Windows\System32\tree.com")) {
    function tree { & "C:\Windows\System32\tree.com" $args }
}

# Function for lazygit with 1Password SSH agent integration
function lg {
    $opSock = & ssh.exe -G github.com | Select-String "^identityagent " | ForEach-Object { $_.Line.Split(" ")[1] }
    if ($opSock) {
        $env:SSH_AUTH_SOCK = $opSock
    }
    & lazygit $args
}

# Initialize interactive tools if available
# Starship prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
    $starshipInit = & starship init powershell 2>$null
    if ($starshipInit) {
        Invoke-Expression ($starshipInit -join "`n")
    }
}

# Zoxide for better cd
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    $zoxideInit = & zoxide init powershell 2>$null
    if ($zoxideInit) {
        Invoke-Expression ($zoxideInit -join "`n")
    }
}



# Ensure proper terminal capabilities for color support
if ($env:TERM -match "256color|truecolor|24bit") {
    $env:COLORTERM = "truecolor"
}
