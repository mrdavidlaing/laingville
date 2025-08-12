Describe "setup-user script"
Before "cd '${SHELLSPEC_PROJECT_ROOT}'"
Before "source ./lib/polyfill.functions.bash"
Before "source ./lib/logging.functions.bash"
Before "source ./lib/security.functions.bash"
Before "source ./lib/shared.functions.bash"
Before "source ./lib/setup-user.functions.bash"

Describe "dry-run mode"
It "shows expected output format"
# Set DOTFILES_DIR to a known good directory for CI compatibility
DOTFILES_DIR="$(cd "${SHELLSPEC_PROJECT_ROOT}/dotfiles/mrdavidlaing" && pwd)"
export DOTFILES_DIR
# Mock platform to ensure consistent systemd behavior across environments
export PLATFORM="arch"

When call ./bin/setup-user --dry-run

The status should be success
The output should include "DRY RUN MODE"
The output should include "SHARED SYMLINKS:"
The output should include "USER SYMLINKS:"
The output should include "PACKAGES"
The output should include "SYSTEMD SERVICES:"
End
End

Describe "argument handling"
It "shows proper error for invalid arguments"
When call ./bin/setup-user --invalid

The status should be failure
The stderr should include "Unknown option"
The stdout should be blank
End
End

Describe "missing packages.yml handling"
It "handles missing packages.yml gracefully"
# Create temporary dotfiles directory within allowed path
temp_dir="${SHELLSPEC_PROJECT_ROOT}/dotfiles/test_temp_user_$$"
mkdir -p "${temp_dir}/.config"
echo "test" > "${temp_dir}/.config/test.conf"
export DOTFILES_DIR="${temp_dir}"

When call ./bin/setup-user --dry-run

The status should be success
The output should include "No packages.yml found"

# Cleanup
rm -rf "${temp_dir}"
End
End

Describe "shared dotfiles processing"
It "processes shared dotfiles correctly"
DOTFILES_DIR="$(cd "${SHELLSPEC_PROJECT_ROOT}/dotfiles/mrdavidlaing" && pwd)"
export DOTFILES_DIR
# Mock platform to ensure shared dotfiles are processed consistently
export PLATFORM="arch"

When call ./bin/setup-user --dry-run

The status should be success
The output should include "dynamic-wallpaper"
The output should include "shared"
End
End

Describe "systemd services"
It "detects systemd services"
DOTFILES_DIR="$(cd "${SHELLSPEC_PROJECT_ROOT}/dotfiles/mrdavidlaing" && pwd)"
export DOTFILES_DIR
# Mock platform to ensure systemd services are detected consistently
export PLATFORM="arch"

When call ./bin/setup-user --dry-run

The status should be success
The output should include "* Would: enable and start: dynamic-wallpaper.timer"
End
End

Describe "dynamic wallpaper script"
It "shows help"
script_path="${SHELLSPEC_PROJECT_ROOT}/dotfiles/shared/.local/bin/dynamic-wallpaper"

When call "${script_path}" --help

The status should be success
The output should include "Dynamic Wallpaper Script"
The output should include "YAML"
The output should include "go-yq"
End
End

Describe "custom scripts"
It "extracts scripts from real config"
DOTFILES_DIR="$(cd "${SHELLSPEC_PROJECT_ROOT}/dotfiles/mrdavidlaing" && pwd)"
export DOTFILES_DIR

When call get_custom_scripts "arch"

The output should not be blank
The output should include "install_claude_code"
End
End

Describe "platform handling"
It "shows correct behavior for unknown platform"
DOTFILES_DIR="$(cd "${SHELLSPEC_PROJECT_ROOT}/dotfiles/mrdavidlaing" && pwd)"
export DOTFILES_DIR

When run bash -c 'export PLATFORM=unknown; ./bin/setup-user --dry-run'

The status should be success
The output should include "Unknown platform: unknown - skipping package installation"
End

It "skips custom scripts gracefully on unknown platform"
# Create temporary dotfiles directory within allowed path
temp_dir="${SHELLSPEC_PROJECT_ROOT}/dotfiles/test_temp_custom_$$"
mkdir -p "${temp_dir}"

# Create packages.yml with custom script (which should be skipped on unknown platform)
cat > "${temp_dir}/packages.yml" << 'EOF'
arch:
  pacman:
    - git
  custom:
    - nonexistent_script
EOF

export DOTFILES_DIR="${temp_dir}"

When run bash -c 'export PLATFORM=unknown; ./bin/setup-user --dry-run'

The status should be success
The output should include "Unknown platform: unknown - skipping package installation"

# Cleanup
rm -rf "${temp_dir}"
End
End
End
