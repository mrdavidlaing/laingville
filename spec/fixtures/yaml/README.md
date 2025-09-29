# YAML Parser Test Fixtures

This directory contains canonical test YAML files used to ensure parity between bash and PowerShell YAML parsers.

## Purpose

To ensure both `extract_packages_from_yaml()` (bash) and `Get-PackagesFromYaml()` (PowerShell) handle YAML parsing consistently, preventing regressions and documenting expected behavior.

## Structure

```
spec/fixtures/yaml/
├── packages-basic.yaml            # Simple list format
├── packages-comments.yaml         # Inline & standalone comments
├── packages-quotes.yaml           # Single & double quoted strings
├── packages-inline-array.yaml     # [item1, item2] format (PowerShell only)
├── packages-mixed.yaml            # Mix of quotes, comments, whitespace
├── packages-empty.yaml            # Empty sections
├── packages-missing-platform.yaml # Missing platform/manager sections
├── expected-outputs.md            # Documents expected parser outputs
└── README.md                      # This file
```

## Test Coverage

### Bash Tests (`spec/yaml_parser_spec.sh`)
**34 test cases** covering:
- ✅ Basic list format parsing (all platforms)
- ✅ Comment handling (inline and standalone)
- ✅ Quote handling (single and double)
- ✅ Mixed formatting
- ✅ Empty sections
- ✅ Missing platforms/managers
- ✅ Error handling (invalid files, injection attacks)
- ✅ Real-world config files

### PowerShell Tests (`spec/powershell/yaml.functions.Tests.ps1`)
**26 test cases** covering:
- ✅ Basic list format parsing (Windows only)
- ✅ Inline array format `[item1, item2]`
- ✅ Comment handling
- ✅ Quote handling
- ✅ Empty sections
- ✅ Missing sections
- ✅ Error handling (malformed YAML)
- ✅ Symlink parsing

## Key Differences

### Platform Scope
- **Bash parser**: Cross-platform - extracts from any platform section (arch, wsl, windows, macos)
- **PowerShell parser**: Windows-only - only extracts from `windows:` section

### Inline Arrays
- **Bash parser**: Does NOT support inline array format `[item1, item2]`
- **PowerShell parser**: Supports both list format and inline arrays

## Running Tests

### Bash Tests
```bash
shellspec spec/yaml_parser_spec.sh
```

### PowerShell Tests
```bash
pwsh -Command "Invoke-Pester -Path ./spec/powershell/yaml.functions.Tests.ps1"
```

## Test Results

As of 2025-09-29:
- **Bash**: 34 examples, 0 failures ✅
- **PowerShell**: 26 examples, 0 failures ✅

## Improvements Made

1. **Added single quote stripping** to bash parser (previously only stripped double quotes)
2. **Comprehensive test coverage** increased from 2 bash tests to 34 tests
3. **Shared test fixtures** ensure consistent behavior across implementations
4. **Documentation** clarifies expected behavior and platform differences