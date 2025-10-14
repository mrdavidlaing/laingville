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

    # Use explicit character codes instead of backtick escape sequences
    # which may not work correctly on non-Windows PowerShell
    $CR = [char]0x0D
    $LF = [char]0x0A
    $CRLF = "$CR$LF"

    # Convert all line endings to CRLF
    # First normalize CRLF to LF
    $content = $content.Replace($CRLF, "$LF")
    # Then convert all LF to CRLF
    $content = $content.Replace("$LF", $CRLF)

    # Remove trailing whitespace from each line
    $content = $content -replace "[ \t]+$CR$LF", $CRLF

    # Write content as bytes first
    $contentBytes = $utf8NoBom.GetBytes($content)
    [System.IO.File]::WriteAllBytes($FilePath, $contentBytes)

    # Append CRLF bytes directly using FileStream (more reliable than byte array concatenation)
    $fs = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
    try {
        $fs.WriteByte(0x0D)  # CR
        $fs.WriteByte(0x0A)  # LF
    }
    finally {
        $fs.Close()
    }

    exit 0
}
catch {
    Write-Host "ERROR in ensure-crlf.ps1: $_" -ForegroundColor Red
    exit 1
}
