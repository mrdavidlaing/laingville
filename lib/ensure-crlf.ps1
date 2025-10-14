param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
)

try {
    # Read the file as bytes to avoid any platform-specific line ending interpretation
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $content = $utf8NoBom.GetString($bytes)

    # Remove all trailing whitespace and newlines
    $content = $content.TrimEnd()

    # Convert all line endings to CRLF
    # First normalize CRLF to LF
    $content = $content.Replace("`r`n", "`n")
    # Then convert all LF to CRLF
    $content = $content.Replace("`n", "`r`n")

    # Remove trailing whitespace from each line
    $content = $content -replace '[ \t]+\r\n', "`r`n"

    # Add exactly one CRLF at the end using explicit byte values
    # Append CR (0x0D) and LF (0x0A) as bytes to ensure platform independence
    $contentBytes = $utf8NoBom.GetBytes($content)
    $crlfBytes = [byte[]]@(0x0D, 0x0A)
    $finalBytes = $contentBytes + $crlfBytes

    [System.IO.File]::WriteAllBytes($FilePath, $finalBytes)

    exit 0
}
catch {
    Write-Host "ERROR in ensure-crlf.ps1: $_" -ForegroundColor Red
    exit 1
}
