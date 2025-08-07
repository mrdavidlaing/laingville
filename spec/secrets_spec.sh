Describe "setup.sh secrets"
  Before "cd '$SHELLSPEC_PROJECT_ROOT'"
  Before "source ./lib/polyfill.functions.bash"
  Before "source ./lib/security.functions.bash"
  Before "source ./lib/shared.functions.bash"

  It "usage includes secrets command"
    When call ./setup.sh
    The status should be failure
    The stderr should include "secrets"
    The stderr should include "Usage: ./setup.sh {user|server|secrets}"
  End

  It "forwards to setup-secrets script"
    When call ./setup.sh secrets --dry-run
    The status should be failure
    The stdout should include "Secure note 'user/mrdavidlaing' not found in Laingville vault"
  End
End
