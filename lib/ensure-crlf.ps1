param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

try {
    # Read the file content
    $content = [System.IO.File]::ReadAllText($FilePath)
    
    # Remove all trailing whitespace and newlines
    $content = $content.TrimEnd()
    
    # Convert all line endings to CRLF
    # First normalize CRLF to LF
    $content = $content.Replace("`r`n", "`n")
    # Then convert all LF to CRLF
    $content = $content.Replace("`n", "`r`n")
    
    # Remove trailing whitespace from each line
    $content = $content -replace '[ \t]+\r\n', "`r`n"
    
    # Add exactly one CRLF at the end
    $content = $content + "`r`n"
    
    # Write as bytes to avoid any platform-specific line ending conversion
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $bytes = $utf8NoBom.GetBytes($content)
    [System.IO.File]::WriteAllBytes($FilePath, $bytes)
    
    exit 0
} catch {
    Write-Host "ERROR in ensure-crlf.ps1: $_" -ForegroundColor Red
    exit 1
}

