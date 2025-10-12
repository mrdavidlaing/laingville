[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()

# PowerShell script to lint all .ps1 files using PSScriptAnalyzer

if (Get-Module -ListAvailable PSScriptAnalyzer) {
    Write-Host "Linting PowerShell scripts with PSScriptAnalyzer..."

    $files = Get-ChildItem -Path . -Include *.ps1 -Recurse | Where-Object { $_.FullName -notmatch '\.git' }

    if ($files.Count -eq 0) {
        Write-Host "No PowerShell files found to lint."
        exit 0
    }

    $issueCount = 0
    foreach ($file in $files) {
        Write-Host "Checking $($file.Name)"
        $results = Invoke-ScriptAnalyzer -Path $file.FullName -Severity Warning, Error
        if ($results) {
            $issueCount += $results.Count
            $results | Format-Table -AutoSize
        }
    }

    if ($issueCount -eq 0) {
        Write-Host "No issues found in PowerShell scripts"
    }
    else {
        Write-Host "Found $issueCount issues in PowerShell scripts"
        exit 1
    }
}
else {
    Write-Host "PSScriptAnalyzer not found. Install with: Install-Module -Name PSScriptAnalyzer"
    exit 1
}

