# Pester configuration for laingville PowerShell tests
# This configuration follows the same patterns as ShellSpec for consistency

@{
    Run          = @{
        Path          = @('./spec/powershell')
        ExcludePath   = @()
        ScriptBlock   = @()
        Container     = @()
        TestExtension = '.Tests.ps1'
        Exit          = $false
        Throw         = $false
        PassThru      = $true
        SkipRun       = $false
    }

    Filter       = @{
        Tag         = @()
        ExcludeTag  = @()
        Line        = @()
        ExcludeLine = @()
        FullName    = @()
    }

    CodeCoverage = @{
        Enabled        = $true
        Path           = @('./lib/*.ps1', './bin/*.ps1')
        RecursePaths   = $true
        OutputFormat   = 'JaCoCo'
        OutputPath     = './coverage.xml'
        OutputEncoding = 'UTF8'
        ExcludeTests   = $true
        UseBreakpoints = $true
    }

    Output       = @{
        Verbosity           = 'Detailed'
        StackTraceVerbosity = 'Filtered'
        CIFormat            = 'Auto'
    }

    Should       = @{
        ErrorAction = 'Stop'
    }

    Debug        = @{
        ShowFullErrors         = $false
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = @()
        ShowNavigationMarkers  = $false
        ReturnRawResultObject  = $false
    }

    TestResult   = @{
        Enabled        = $true
        OutputFormat   = 'NUnitXml'
        OutputPath     = './testresults.xml'
        OutputEncoding = 'UTF8'
        TestSuiteName  = 'Laingville PowerShell Tests'
    }
}
