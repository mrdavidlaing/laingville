#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  source ./lib/polyfill.functions.bash
  source ./lib/security.functions.bash
  source ./lib/shared.functions.bash
}

@test "get_packages extracts packages from real config" {
  export DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/../dotfiles/mrdavidlaing" && pwd)"
  result=$(get_packages_from_file "arch" "pacman" "$DOTFILES_DIR/packages.yml")
  [ -n "$result" ]
  [[ "$result" =~ "hyprland" ]]
}

@test "server packages.yml parsing extracts packages correctly" {
  temp_dir=$(mktemp -d)
  server_dir="$temp_dir/servers/testhost"
  mkdir -p "$server_dir"
  cat > "$server_dir/packages.yml" << 'EOF'
arch:
  pacman:
    - k3s
    - htop
    - curl
  aur:
    - some-aur-package

windows:
  winget:
    - SomeApp
EOF
  result=$(get_packages_from_file "arch" "pacman" "$server_dir/packages.yml")
  [[ "$result" =~ "k3s" ]]
  [[ "$result" =~ "htop" ]]
  rm -rf "$temp_dir"
}

@test "validate_script_name accepts valid names" {
  run validate_script_name valid_name
  [ "$status" -eq 0 ]
}

@test "validate_script_name rejects invalid characters" {
  run validate_script_name "bad_name!"
  [ "$status" -ne 0 ]
}

@test "validate_script_name rejects path traversal" {
  run validate_script_name "../evil"
  [ "$status" -ne 0 ]
}

@test "validate_script_name rejects too long" {
  longname=$(printf 'a%.0s' {1..60})
  run validate_script_name "$longname"
  [ "$status" -ne 0 ]
}
