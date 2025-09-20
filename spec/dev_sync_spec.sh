#!/usr/bin/env bash

Describe 'dev-sync tool'
  Describe './bin/dev-sync'
    Context 'without hostname argument'
      It 'shows usage error'
        When run ./bin/dev-sync
        The stderr should include 'Usage:'
        The status should equal 1
      End
    End

    Context 'with help option'
      It 'shows usage information'
        When run ./bin/dev-sync --help
        The error should include 'Usage:'
        The error should include 'Development sync tool'
        The status should equal 1
      End

      It 'shows usage with -h'
        When run ./bin/dev-sync -h
        The error should include 'Usage:'
        The status should equal 1
      End
    End

    Context 'with invalid hostname'
      It 'rejects hostname with invalid characters'
        When run ./bin/dev-sync 'invalid/hostname'
        The stderr should include 'Invalid hostname'
        The status should equal 1
      End

      It 'rejects empty hostname'
        When run ./bin/dev-sync ''
        The stderr should include 'Usage:'
        The status should equal 1
      End
    End

    Context 'with nonexistent server'
      It 'reports server directory not found'
        When run ./bin/dev-sync nonexistent-server
        The stderr should include 'Server directory not found'
        The stderr should include 'Available servers:'
        The status should equal 1
      End
    End

    Context 'with missing .dev-sync config'
      setup() {
      mkdir -p servers/testserver
      }

      cleanup() {
      rm -rf servers/testserver
      }

      Before 'setup'
        After 'cleanup'

          It 'reports missing config file'
            When run ./bin/dev-sync testserver
            The stderr should include 'No .dev-sync config found'
            The stderr should include 'CONNECTION=user@hostname'
            The status should equal 1
          End
        End

        Context 'with invalid config'
          setup() {
          mkdir -p servers/testserver
          echo 'INVALID_CONFIG=value' > servers/testserver/.dev-sync
          }

          cleanup() {
          rm -rf servers/testserver
          }

          Before 'setup'
            After 'cleanup'

              It 'reports missing CONNECTION in config'
                When run ./bin/dev-sync testserver
                The stderr should include 'CONNECTION not set'
                The status should equal 1
              End
            End

            Context 'with valid config in dry-run mode'
              setup() {
              mkdir -p servers/testserver/configs
              echo 'test file' > servers/testserver/configs/test.conf
        cat > servers/testserver/.dev-sync << 'EOF'
CONNECTION=testuser@testhost
REMOTE_PATH=/opt/test
EOF

        # Mock rsync and ssh commands
        rsync() {
          echo "rsync $*" >&2
          if [[ "$*" == *"--dry-run"* ]]; then
            echo "Would sync files"
          else
            echo "Syncing files"
          fi
        }
        export -f rsync

        ssh() {
          echo "ssh $*" >&2
          echo "Remote command executed"
        }
        export -f ssh
      }

      cleanup() {
        rm -rf servers/testserver
      }

      Before 'setup'
      After 'cleanup'

      It 'shows what would be synced without making changes'
        When run ./bin/dev-sync testserver --dry-run
        The output should include 'DRY RUN MODE'
        The output should include 'Development sync to testserver'
        The output should include 'Connection: testuser@testhost'
        The output should include 'Remote path: /opt/test'
        The stderr should include 'rsync'
        The stderr should include '--dry-run'
        The status should equal 0
      End
    End

    Context 'with unknown option'
      It 'reports unknown option error'
        When run ./bin/dev-sync testserver --invalid-option
        The stderr should include 'Unknown option'
        The status should equal 1
      End
    End
  End
End
