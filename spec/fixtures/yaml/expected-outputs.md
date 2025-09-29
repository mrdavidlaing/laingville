# Expected Parser Outputs for YAML Fixtures

This document defines the expected behavior for both bash and PowerShell YAML parsers when processing the test fixtures.

## Parser Contract

Both `extract_packages_from_yaml()` (bash) and `Get-PackagesFromYaml()` (PowerShell) must produce **identical outputs** for the same inputs.

### Important Difference: Platform Scope

- **Bash parser** (`extract_packages_from_yaml`): **Cross-platform** - accepts `platform` parameter and can extract from any platform section (arch, wsl, windows, macos, etc.)
- **PowerShell parser** (`Get-PackagesFromYaml`): **Windows-only** - only extracts packages from the `windows:` section

This difference is by design:
- Bash scripts run on Linux/macOS/WSL and need to handle multiple platforms
- PowerShell scripts run on Windows and only need Windows packages

**For parity testing**: Compare outputs only for `windows` platform packages.

### Output Format

**Bash**: Newline-separated package names
```
package1
package2
package3
```

**PowerShell**: Array of strings
```powershell
@("package1", "package2", "package3")
```

---

## Test Fixture: `packages-basic.yaml`

### Test: arch/pacman
**Expected Output** (3 packages):
```
git
vim
tmux
```

### Test: arch/yay
**Expected Output** (2 packages):
```
starship
yay
```

### Test: windows/winget
**Expected Output** (3 packages):
```
Git.Git
Microsoft.PowerShell
Microsoft.VisualStudioCode
```

### Test: windows/scoop
**Expected Output** (2 packages):
```
git
versions/wezterm-nightly
```

### Test: windows/psmodule
**Expected Output** (2 packages):
```
PowerShellGet
Pester
```

### Test: macos/homebrew
**Expected Output** (3 packages):
```
git
starship
ripgrep
```

---

## Test Fixture: `packages-comments.yaml`

Comments should be **stripped** from all output.

### Test: arch/pacman
**Expected Output** (3 packages, no comments):
```
git
vim
tmux
```

### Test: arch/yay
**Expected Output** (2 packages, no comments):
```
starship
yay
```

### Test: windows/winget
**Expected Output** (3 packages, no comments):
```
Git.Git
Microsoft.PowerShell
Microsoft.VisualStudioCode
```

### Test: windows/scoop
**Expected Output** (1 package, no comments):
```
versions/wezterm-nightly
```

---

## Test Fixture: `packages-quotes.yaml`

Quotes should be **stripped** from all output.

### Test: arch/pacman
**Expected Output** (3 packages, quotes removed):
```
git
vim
tmux
```

### Test: arch/yay
**Expected Output** (2 packages, quotes removed):
```
starship
yay
```

### Test: windows/winget
**Expected Output** (3 packages, quotes removed):
```
Git.Git
Microsoft.PowerShell
Microsoft.VisualStudioCode
```

---

## Test Fixture: `packages-inline-array.yaml`

**Note**: Bash parser currently does NOT support inline array format `[item1, item2]`

### Test: windows/winget (PowerShell only)
**Expected Output** (2 packages):
```
Git.Git
Microsoft.PowerShell
```

### Test: arch/pacman (PowerShell only)
**Expected Output** (3 packages):
```
git
vim
tmux
```

---

## Test Fixture: `packages-mixed.yaml`

Should handle quotes + comments + varying whitespace.

### Test: arch/pacman
**Expected Output** (4 packages, quotes and comments stripped):
```
git
vim
tmux
bash
```

### Test: windows/winget
**Expected Output** (3 packages, quotes and comments stripped):
```
Git.Git
Microsoft.PowerShell
Microsoft.VisualStudioCode
```

---

## Test Fixture: `packages-empty.yaml`

Empty sections should return **empty output** (not error).

### Test: arch/pacman (empty section)
**Expected Output**: Empty (no packages)

### Test: windows/winget (empty section)
**Expected Output**: Empty (no packages)

### Test: windows/psmodule (empty section)
**Expected Output**: Empty (no packages)

### Test: arch/yay (has packages)
**Expected Output** (1 package):
```
starship
```

---

## Test Fixture: `packages-missing-platform.yaml`

Missing platforms should return **empty output** (not error).

### Test: wsl/pacman (platform doesn't exist)
**Expected Output**: Empty (no packages)

### Test: windows/winget (platform doesn't exist)
**Expected Output**: Empty (no packages)

### Test: arch/pacman (platform exists)
**Expected Output** (2 packages):
```
git
vim
```

---

## Error Handling

Both parsers must handle these scenarios gracefully:

1. **Non-existent file**: Return empty output or error status
2. **Malformed YAML**: Return empty output or error status
3. **Invalid platform key**: Return empty output or error status
4. **Invalid manager key**: Return empty output or error status

---

## Implementation Notes

### Bash Implementation (`lib/packages.functions.bash`)
- Uses `sed` and `grep` for parsing
- Security validation via `validate_yaml_key()` and `validate_yaml_file()`
- Limits to first 1000 lines and 100 packages for safety

### PowerShell Implementation (`lib/yaml.functions.ps1`)
- Uses regex matching for parsing
- Supports both list format and inline array format
- Returns hashtable with keys: `winget`, `scoop`, `psmodule`, `pacman`, `aur`

---

## Test Coverage Goals

- ✓ List format parsing
- ✓ Comment handling (inline and standalone)
- ✓ Quote handling (single and double)
- ✓ Empty sections
- ✓ Missing sections
- ✓ Missing platforms
- ✓ Multiple package managers
- ⚠ Inline array format (PowerShell only)
- ✓ Error handling (malformed files)