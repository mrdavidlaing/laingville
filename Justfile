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

# Run tests for changed files (selective testing)
test-changed:
    #!/usr/bin/env bash
    echo "🧪 Running tests for changed files..."
    ./scripts/run-changed-tests.sh

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

# ============================================
# Pensive Assistant Feature Development
# ============================================

# Build the pensive-assistant feature (mirrors CI build)
# Usage: just pensive-assistant-build [amd64|arm64|native]
pensive-assistant-build ARCH="native":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if Docker is available
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker is not running. Please start Colima or Docker Desktop."
        exit 1
    fi

    # Determine platform flag and output suffix
    if [ "{{ARCH}}" = "native" ]; then
        PLATFORM=""
        SUFFIX=""
        echo "Building for native architecture..."
    else
        PLATFORM="--platform linux/{{ARCH}}"
        SUFFIX="-{{ARCH}}"
        echo "Building for architecture: {{ARCH}}"
    fi

    # Use a temp dir under $HOME to ensure Docker can mount it on macOS
    FEATURE_BUILD_DIR=$(mktemp -d "$HOME/.pensive-assistant-build${SUFFIX}.XXXXXX")
    trap "rm -rf $FEATURE_BUILD_DIR" EXIT

    echo "Copying feature files to $FEATURE_BUILD_DIR..."
    cp -r .devcontainer/features/pensive-assistant/* "$FEATURE_BUILD_DIR/"

    echo "Running build inside devcontainer base image (mirrors CI)..."
    docker run --rm $PLATFORM \
        --user root \
        --privileged \
        -v "$FEATURE_BUILD_DIR:/workspace" \
        ghcr.io/mrdavidlaing/laingville/laingville-devcontainer:latest \
        bash /workspace/build-delta-tarball.sh

    echo ""
    echo "=== Copying results to .devcontainer/features/pensive-assistant/dist${SUFFIX}/ ==="
    mkdir -p ".devcontainer/features/pensive-assistant/dist${SUFFIX}"
    rm -rf ".devcontainer/features/pensive-assistant/dist${SUFFIX}/"*
    cp "$FEATURE_BUILD_DIR/dist/"* ".devcontainer/features/pensive-assistant/dist${SUFFIX}/"
    chmod -R u+w ".devcontainer/features/pensive-assistant/dist${SUFFIX}/"
    ls -lh ".devcontainer/features/pensive-assistant/dist${SUFFIX}/"

    echo ""
    echo "Build complete: .devcontainer/features/pensive-assistant/dist${SUFFIX}/"

# Test the pensive-assistant nix environment locally
pensive-assistant-shell:
    cd .devcontainer/features/pensive-assistant && nix develop

# Launch a coding agent in devcontainer (full yolo mode)
# Usage: just dev-agent [claude-code|opencode] [task...]
# Default: claude-code, interactive mode if no task provided
dev-agent agent_type="claude-code" *task:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Normalize agent type and set yolo flags
    AGENT_TYPE="{{ agent_type }}"
    TASK="{{ task }}"
    
    case "$AGENT_TYPE" in
        claude|claude-code|cc)
            AGENT_CMD="claude"
            AGENT_NAME="Claude Code"
            YOLO_FLAG="--dangerously-skip-permissions"
            ;;
        opencode|omo|oc)
            AGENT_CMD="opencode"
            AGENT_NAME="OpenCode"
            # OpenCode run command with implicit auto-approve in agent mode
            YOLO_FLAG="run"
            ;;
        *)
            echo "❌ Unknown agent type: $AGENT_TYPE"
            echo ""
            echo "Supported agents:"
            echo "  • claude-code (default): claude, cc"
            echo "  • opencode: opencode, omo, oc"
            exit 1
            ;;
    esac
    
    # Check if devcontainer is running
    # Use current directory to determine project name (same logic as .devcontainer/bin/ctl)
    PROJECT_NAME="laingville"
    COMPOSE_PROJECT="${PROJECT_NAME}_devcontainer"
    
    if ! docker compose -p "$COMPOSE_PROJECT" ps --quiet devcontainer 2>/dev/null | grep -q .; then
        echo "🚀 Starting devcontainer..."
        just dev-up
        echo ""
        sleep 2
    fi
    
    echo "🤖 Launching $AGENT_NAME in devcontainer (yolo mode)..."
    echo ""
    echo "   Yolo flags: $YOLO_FLAG"
    echo "   Capabilities: Full filesystem access, no approval prompts"
    echo "   Blast radius: Container + your GitHub token (via GITHUB_TOKEN env var)"
    echo "   Working directory: /workspace (your repo mounted here)"
    echo ""
    
    # Build and execute command
    if [ -z "$TASK" ]; then
        # Interactive mode
        if [ "$AGENT_CMD" = "claude" ]; then
            FULL_CMD="$AGENT_CMD $YOLO_FLAG"
        else
            # OpenCode interactive doesn't use run flag
            FULL_CMD="$AGENT_CMD"
        fi
    else
        # Task mode with yolo flags
        if [ "$AGENT_CMD" = "claude" ]; then
            FULL_CMD="$AGENT_CMD $YOLO_FLAG '$TASK'"
        else
            # OpenCode: run [message...]
            FULL_CMD="$AGENT_CMD $YOLO_FLAG $TASK"
        fi
    fi
    
    # Execute agent in container
    docker compose -p "$COMPOSE_PROJECT" exec \
        -it \
        -w /workspace \
        devcontainer \
        bash -c "$FULL_CMD"

# Help recipe
help:
    @echo "Laingville Justfile - Available recipes:"
    @echo ""
    @echo "  just              - Run format, lint, and test (default)"
    @echo "  just format       - Format all bash scripts with shfmt"
    @echo "  just lint         - Lint bash + PowerShell scripts (if pwsh available)"
    @echo "  just test         - Run all tests (bash + PowerShell)"
    @echo "  just test-bash    - Run bash tests with shellspec"
    @echo "  just test-changed - Run tests for changed files only (faster)"
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
    @echo "Pensive Assistant Feature:"
    @echo "  just pensive-assistant-build [arch] - Build feature tarball (native/amd64/arm64)"
    @echo "  just pensive-assistant-shell        - Enter nix development shell"
    @echo ""
    @echo "Agent (yolo mode):"
    @echo "  just dev-agent [type] [task...]"
    @echo ""
    @echo "  Types (default: claude-code):"
    @echo "    claude-code, cc, claude     Claude Code (flag: --dangerously-skip-permissions)"
    @echo "    opencode, omo, oc           OpenCode (command: run)"
    @echo ""
    @echo "  Examples:"
    @echo "    just dev-agent                           # Claude Code interactive"
    @echo "    just dev-agent cc 'Implement auth'       # Claude Code task"
    @echo "    just dev-agent opencode                  # OpenCode interactive"
    @echo "    just dev-agent omo 'Fix bugs'            # OpenCode task"
    @echo ""
    @echo "  just help         - Show this help message"
    @echo "  just --list       - List all available recipes (built-in)"
    @echo ""
    @echo "Recommended workflow:"
    @echo "  1. just           (format, lint, and all tests)"
    @echo "  2. just test-bash (run only bash tests for faster iteration)"

