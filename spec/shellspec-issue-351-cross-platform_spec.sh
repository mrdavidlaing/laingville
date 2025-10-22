#!/bin/bash

# ============================================================================
# Cross-Platform Test for ShellSpec Issue #351
# https://github.com/shellspec/shellspec/issues/351
# ============================================================================
#
# PURPOSE: Determine if the reporter bug is WSL-specific or affects all platforms
#
# HYPOTHESIS: If WSL-specific, this test should:
#   - FAIL on WSL (calling .exe binaries)
#   - PASS on native Linux (calling native binaries)
#   - PASS on macOS (calling native binaries)
#   - Result tells us if it's a WSL boundary issue or general ShellSpec issue
#
# The test adapts to the platform:
#   - WSL: calls pwsh.exe (Windows binary, crosses WSL boundary)
#   - Native Linux/macOS: calls bash (native binary, no boundary crossing)
#
# Run with: shellspec spec/shellspec-issue-351-cross-platform_spec.sh
# ============================================================================

# Detect if we're on WSL
is_wsl() {
if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
return 0
fi
return 1
}

Describe "ShellSpec Issue #351 - Cross-Platform Test"
  It "single test calling platform-appropriate binary"
    # On WSL: call a Windows .exe binary (should trigger bug)
    # On native Linux/macOS: call a native binary (should NOT trigger if WSL-specific)
    if is_wsl && command -v pwsh.exe >/dev/null 2>&1; then
      # WSL: call Windows binary
    pwsh.exe -NoProfile -Command ":" > /dev/null 2>&1 || true
    else
      # Native Linux/macOS: call native binary with same pattern
    bash -c ":" > /dev/null 2>&1 || true
    fi

    When run echo "test"
    The output should equal "test"
  End
End
