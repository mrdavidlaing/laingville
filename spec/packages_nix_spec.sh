#!/usr/bin/env bash

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218

Describe "Nix package management"
  Include lib/logging.functions.bash
  Include lib/security.functions.bash
  Include lib/polyfill.functions.bash
  Include lib/packages.functions.bash

  # Cleanup temp directories after each test
  AfterEach 'cleanup_temp_dir'

  cleanup_temp_dir() {
  if [[ -n "${temp_dir:-}" && -d "${temp_dir}" ]]; then
  rm -rf "${temp_dir}"
  unset temp_dir
  fi
  }

  Describe "initialize_nix_environment()"
    It "shows dry-run output"
      When call initialize_nix_environment true

      The output should include "Would: initialize nix environment"
      The status should be success
    End

    It "sources user profile nix.sh when present"
      temp_dir=$(mktemp -d)
      profile_dir="${temp_dir}/.nix-profile/etc/profile.d"
      mkdir -p "${profile_dir}"
cat > "${profile_dir}/nix.sh" << 'EOF'
export NIX_TEST_VAR="1"
EOF

      When run bash -c "export HOME='${temp_dir}'; source ./lib/logging.functions.bash; source ./lib/security.functions.bash; source ./lib/polyfill.functions.bash; source ./lib/packages.functions.bash; initialize_nix_environment false; echo \"\${NIX_TEST_VAR}\""

      The output should include "Nix environment initialized"
      The output should include "1"
      The status should be success
    End

  End
End
