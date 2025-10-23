# ShellSpec Issue #351 - Workaround for WSL Users

**Issue:** ShellSpec reporter crashes when tests call Windows `.exe` binaries on WSL
**Issue Link:** https://github.com/shellspec/shellspec/issues/351

## 🎯 Simple Workaround: Install Native Linux PowerShell

The bug is triggered by calling Windows binaries (like `pwsh.exe`) from WSL. The workaround is to **use native Linux binaries instead**.

### Why This Works

- ✅ `pwsh.exe` (Windows PowerShell) → **Triggers bug** (WSL → Windows boundary)
- ✅ `pwsh` (Linux PowerShell) → **Does NOT trigger bug** (native Linux binary)

Our `format-files.sh` script already prefers native Linux PowerShell:

```bash
if command -v pwsh > /dev/null 2>&1; then
  pwsh_cmd="pwsh"
elif command -v pwsh.exe > /dev/null 2>&1; then
  pwsh_cmd="pwsh.exe"
fi
```

So installing native PowerShell automatically fixes the issue!

## Installation

### Ubuntu/Debian on WSL

```bash
# Update package list
sudo apt-get update

# Install prerequisites
sudo apt-get install -y wget apt-transport-https software-properties-common

# Download Microsoft repository GPG key
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"

# Register the Microsoft repository
sudo dpkg -i packages-microsoft-prod.deb

# Update package list
sudo apt-get update

# Install PowerShell
sudo apt-get install -y powershell

# Verify installation
pwsh --version
```

### Alternative: Snap (if available)

```bash
sudo snap install powershell --classic
```

### Verify the Workaround

After installation, verify that native `pwsh` is being used:

```bash
command -v pwsh
# Should output: /usr/bin/pwsh (not /mnt/c/...)

pwsh --version
# Should output: PowerShell 7.x.x
```

## Testing the Fix

Run the tests that previously triggered the bug:

```bash
# These should now pass cleanly without reporter errors
shellspec spec/format_line_endings.reporter-bug_spec.sh
shellspec spec/format_whitespace.reporter-bug_spec.sh

# Or run all tests
make test-bash
```

## Why Not Always Use Windows PowerShell?

**Performance:** Native Linux PowerShell is faster than Windows PowerShell called via WSL interop.

**Compatibility:** Native Linux PowerShell avoids the WSL → Windows boundary that causes the reporter bug.

**Path handling:** No need for `wslpath` conversions when using native Linux paths.

## Current Sidecar File Approach

Even without installing native PowerShell, the sidecar file approach (`*.reporter-bug_spec.sh`) works:

1. Problematic tests isolated in separate files
2. Run with error suppression in Makefile
3. Tests still validate functionality, just suppress reporter errors

However, **installing native Linux PowerShell is the better solution** as it:
- ✅ Eliminates the root cause
- ✅ Improves performance
- ✅ Simplifies test infrastructure
- ✅ No need for error suppression

## Summary

| Approach | Pros | Cons |
|----------|------|------|
| **Install native Linux pwsh** | ✅ Fixes root cause<br>✅ Better performance<br>✅ No special handling needed | Requires installation |
| **Sidecar files + error suppression** | ✅ Works without changes<br>✅ Documents the issue | ❌ Doesn't fix root cause<br>❌ More complex infrastructure |
| **Use pwsh.exe** (current default if no pwsh) | ✅ Already installed on Windows | ❌ Triggers ShellSpec bug<br>❌ Slower (WSL interop) |

**Recommendation:** Install native Linux PowerShell for the best experience.

## Related Documentation

- **Main investigation:** `docs/shellspec-issue-351-BREAKTHROUGH.md`
- **Cross-platform test:** `spec/shellspec-issue-351-cross-platform_spec.sh`
- **Format script logic:** `scripts/format-files.sh` (lines 176-287)
