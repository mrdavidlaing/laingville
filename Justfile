# Justfile for Laingville repository
# Provides canonical commands for formatting, linting, and testing bash scripts

# Default recipe: run format, lint, then test
default:
    @just format
    @just lint
    @just test
    @echo "✅ All checks passed!"

# Format all scripts using centralized batch formatter
format:
    #!/usr/bin/env bash
    echo "🎨 Formatting scripts..."
    files_to_format=$(find . -type f \( -name "*.sh" -o -name "*.bash" -o -name "*.ps1" \) \
        -not -path "./.git/*" \
        -not -path "./.worktrees/*" \
        -not -path "./dotfiles/*/.*" \
        -not -path "./spec/fixtures/*" \
        2>/dev/null)
    claude_scripts=$(find ./dotfiles/mrdavidlaing/.claude/scripts -type f -name "*.bash" 2>/dev/null || true)
    claude_wrappers=$(find ./dotfiles/mrdavidlaing/.claude/wrappers -type f 2>/dev/null || true)
    all_files="$files_to_format $claude_scripts $claude_wrappers"
    if [ -n "$all_files" ]; then
        ./scripts/format-files.sh --batch $all_files
    else
        echo "ℹ️  No files found to format"
    fi

# Lint all bash scripts using shellcheck, and PowerShell scripts if pwsh is available
# Note: On Windows, skip bash linting to avoid xargs/WSL conflicts in CI
lint:
    #!/usr/bin/env bash
    if [ "$(uname -s 2>/dev/null | grep -i 'MINGW\|MSYS\|CYGWIN')" ]; then
        echo "ℹ️  Windows detected. Skipping bash linting (not reliable in Windows CI environments)"
    else
        echo "🔍 Linting bash scripts..."
        ./scripts/lint-bash.sh
    fi
    if command -v pwsh >/dev/null 2>&1; then
        echo "🔍 Linting PowerShell scripts..."
        pwsh -ExecutionPolicy Bypass -File scripts/lint-powershell.ps1
    else
        echo "ℹ️  PowerShell not available. Skipping PowerShell linting"
    fi

# Run all tests (bash + PowerShell)
test:
    @just test-bash
    @just test-powershell
    @echo "✅ All tests completed!"

# Run bash tests using shellspec
test-bash:
    #!/usr/bin/env bash
    echo "🧪 Running bash tests..."
    if command -v shellspec >/dev/null 2>&1; then
        shellspec
    else
        echo "⚠️  shellspec not found. Skipping bash tests"
        exit 1
    fi

# Run PowerShell tests using Pester
test-powershell:
    #!/usr/bin/env bash
    echo "🧪 Running PowerShell tests..."
    if command -v pwsh >/dev/null 2>&1; then
        if [ -f ".pester.ps1" ] && [ -d "spec/powershell" ]; then
            if pwsh -NoProfile -Command "if (Get-Module -ListAvailable Pester) { exit 0 } else { exit 1 }" 2>/dev/null; then
                pwsh -NoProfile -Command "Invoke-Pester -Path ./spec/powershell -Output Detailed"
            else
                echo "ℹ️  Pester not installed. Skipping PowerShell tests"
                echo "    Install with: pwsh -Command 'Install-Module -Name Pester -Force'"
            fi
        else
            echo "ℹ️  No PowerShell tests found. Skipping PowerShell tests"
        fi
    else
        echo "ℹ️  PowerShell not available. Skipping PowerShell tests"
    fi

# Check without modifying (CI-friendly)
check:
    #!/usr/bin/env bash
    echo "📋 Checking format..."
    files_to_check=$(find . -type f \( -name "*.sh" -o -name "*.bash" -o -name "*.ps1" \) \
        -not -path "./.git/*" \
        -not -path "./.worktrees/*" \
        -not -path "./dotfiles/*/.*" \
        -not -path "./spec/fixtures/*" \
        2>/dev/null)
    claude_scripts=$(find ./dotfiles/mrdavidlaing/.claude/scripts -type f -name "*.bash" 2>/dev/null || true)
    claude_wrappers=$(find ./dotfiles/mrdavidlaing/.claude/wrappers -type f 2>/dev/null || true)
    all_files="$files_to_check $claude_scripts $claude_wrappers"
    if [ -n "$all_files" ]; then
        ./scripts/format-files.sh --check --batch $all_files || exit 1
    else
        echo "ℹ️  No files found to check"
    fi
    @just lint
    @just test

# Devcontainer management
dev-up:
    @.devcontainer/bin/ctl up

dev-down:
    @.devcontainer/bin/ctl down

dev-shell:
    @.devcontainer/bin/ctl shell

dev-status:
    @.devcontainer/bin/ctl status

dev-rebuild:
    @just dev-down
    @echo "🔄 Pulling latest image..."
    @docker compose -f .devcontainer/docker-compose.yml pull
    @just dev-up

# Help recipe
help:
    @echo "Laingville Justfile - Available recipes:"
    @echo ""
    @echo "  just              - Run format, lint, and test (default)"
    @echo "  just format       - Format all bash scripts with shfmt"
    @echo "  just lint         - Lint bash + PowerShell scripts (if pwsh available)"
    @echo "  just test         - Run all tests (bash + PowerShell)"
    @echo "  just test-bash    - Run bash tests with shellspec"
    @echo "  just test-powershell - Run PowerShell tests with Pester"
    @echo "  just check        - Check format and run lint/test without modifying files"
    @echo ""
    @echo "Devcontainer:"
    @echo "  just dev-up       - Start devcontainer with GitHub credentials"
    @echo "  just dev-down     - Stop devcontainer"
    @echo "  just dev-shell    - Open interactive shell in running container"
    @echo "  just dev-status   - Show devcontainer service status"
    @echo "  just dev-rebuild  - Pull latest image and restart devcontainer"
    @echo ""
    @echo "  just help         - Show this help message"
    @echo "  just --list       - List all available recipes (built-in)"
    @echo ""
    @echo "Recommended workflow:"
    @echo "  1. just           (format, lint, and all tests)"
    @echo "  2. just test-bash (run only bash tests for faster iteration)"

