#!/bin/bash
# Minimal test case for CRLF conversion debugging

set -e

echo "=== CRLF Conversion Minimal Test Case ==="
echo ""

# Check if PowerShell is available
if command -v pwsh > /dev/null 2>&1; then
    PWSH_CMD="pwsh"
elif command -v pwsh.exe > /dev/null 2>&1; then
    PWSH_CMD="pwsh.exe"
else
    echo "❌ PowerShell not available, skipping test"
    exit 0
fi

echo "✓ Found PowerShell: $PWSH_CMD"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS_SCRIPT="$SCRIPT_DIR/lib/ensure-crlf.ps1"

# Verify script exists
if [[ ! -f "$PS_SCRIPT" ]]; then
    echo "❌ PowerShell script not found: $PS_SCRIPT"
    exit 1
fi
echo "✓ Found ensure-crlf.ps1: $PS_SCRIPT"
echo ""

# Create a test file with LF endings
TEST_FILE=$(mktemp /tmp/test-crlf-XXXXX.ps1)
echo "Created test file: $TEST_FILE"

# Write content with explicit LF endings
printf 'Write-Host "test"  \n' > "$TEST_FILE"
echo ""

# Show initial bytes
echo "--- Initial file bytes (hex) ---"
od -An -tx1 "$TEST_FILE"
echo ""

# Show initial bytes (last 5 characters)
echo "--- Last 5 bytes ---"
tail -c 5 "$TEST_FILE" | od -An -tx1
echo ""

# Call the PowerShell script
echo "--- Calling ensure-crlf.ps1 ---"
if $PWSH_CMD -NoProfile -File "$PS_SCRIPT" -FilePath "$TEST_FILE"; then
    echo "✓ PowerShell script succeeded"
else
    echo "❌ PowerShell script failed with exit code: $?"
    rm -f "$TEST_FILE"
    exit 1
fi
echo ""

# Show final bytes
echo "--- Final file bytes (hex) ---"
od -An -tx1 "$TEST_FILE"
echo ""

# Show final bytes (last 5 characters)
echo "--- Last 5 bytes ---"
tail -c 5 "$TEST_FILE" | od -An -tx1
echo ""

# Check the last 2 bytes
LAST_TWO=$(tail -c 2 "$TEST_FILE" | od -An -tx1 | tr -d ' ')
echo "--- Last 2 bytes (should be 0d0a) ---"
echo "Got: $LAST_TWO"
echo ""

if [[ "$LAST_TWO" == "0d0a" ]]; then
    echo "✅ SUCCESS: File ends with CRLF (0d0a)"
    rm -f "$TEST_FILE"
    exit 0
else
    echo "❌ FAILURE: File does NOT end with CRLF"
    echo "   Expected: 0d0a"
    echo "   Got:      $LAST_TWO"
    
    # Check for trailing spaces
    if grep -q ' $' "$TEST_FILE" 2>/dev/null; then
        echo "   ⚠️  File has trailing spaces"
    fi
    
    # Check line ending type
    if grep -q $'\r' "$TEST_FILE" 2>/dev/null; then
        echo "   ℹ️  File contains CR characters"
    else
        echo "   ℹ️  File does NOT contain any CR characters (only LF)"
    fi
    
    rm -f "$TEST_FILE"
    exit 1
fi

