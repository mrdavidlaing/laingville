Describe "setup.sh secrets"

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218
# shellcheck disable=SC2154  # SHELLSPEC_PROJECT_ROOT is set by shellspec framework
  Before "cd '${SHELLSPEC_PROJECT_ROOT}'"
    Before "source ./lib/polyfill.functions.bash"
      Before "source ./lib/logging.functions.bash"
        Before "source ./lib/security.functions.bash"
          Before "source ./lib/platform.functions.bash"
            Before "source ./lib/packages.functions.bash"
              Before "source ./lib/shared.functions.bash"

                It "usage includes secrets command"
                  When call ./setup.sh
                  The status should be failure
                  The stderr should include "secrets"
                  The stderr should include "Usage: ./setup.sh {user|server|secrets}"
                End

              End
