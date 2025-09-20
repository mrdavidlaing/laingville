#!/usr/bin/env bash

Describe 'Router platform detection'
  Include lib/platform.functions.bash

  Describe 'detect_platform()'
    Context 'when on router-merlin system'
      setup() {
        # Mock the router-merlin environment
      original_dropbear=""
      original_jffs=""

      if [[ -f /usr/sbin/dropbear ]]; then
      original_dropbear="exists"
      else
      touch /usr/sbin/dropbear 2>/dev/null || true
      fi

      if [[ -d /jffs ]]; then
      original_jffs="exists"
      else
      mkdir -p /jffs 2>/dev/null || true
      fi
      }

      cleanup() {
        # Clean up mocked environment
      if [[ "$original_dropbear" != "exists" ]]; then
      rm -f /usr/sbin/dropbear 2>/dev/null || true
      fi

      if [[ "$original_jffs" != "exists" ]]; then
      rmdir /jffs 2>/dev/null || true
      fi
      }

      Before 'setup'
        After 'cleanup'

          It 'detects router-merlin platform'
            # Skip test on non-router systems
            Skip if "Platform detection tests require router system" test -x "$(command -v wsl.exe 2>/dev/null)"

            When call detect_platform
            The output should equal 'router-merlin'
          End
        End

        Context 'when dropbear exists but no jffs'
          setup() {
          original_dropbear=""

          if [[ -f /usr/sbin/dropbear ]]; then
          original_dropbear="exists"
          else
          touch /usr/sbin/dropbear 2>/dev/null || true
          fi

        # Ensure /jffs does not exist
          if [[ -d /jffs ]]; then
          rmdir /jffs 2>/dev/null || true
          fi
          }

          cleanup() {
          if [[ "$original_dropbear" != "exists" ]]; then
          rm -f /usr/sbin/dropbear 2>/dev/null || true
          fi
          }

          Before 'setup'
            After 'cleanup'

              It 'does not detect router-merlin platform'
                # Skip test on non-router systems
                Skip if "Platform detection tests require router system" test -x "$(command -v wsl.exe 2>/dev/null)"

                When call detect_platform
                The output should not equal 'router-merlin'
              End
            End
          End

          Context 'when on freshtomato system'
            setup() {
              # Mock the freshtomato environment
            original_httpd=""
            original_www=""
            original_jffs=""

            if [[ -f /usr/sbin/httpd ]]; then
            original_httpd="exists"
            else
            touch /usr/sbin/httpd 2>/dev/null || true
            fi

            if [[ -d /www ]]; then
            original_www="exists"
            else
            mkdir -p /www 2>/dev/null || true
            fi

            if [[ -d /jffs ]]; then
            original_jffs="exists"
            else
            mkdir -p /jffs 2>/dev/null || true
            fi
            }

            cleanup() {
              # Clean up mocked environment
            if [[ "$original_httpd" != "exists" ]]; then
            rm -f /usr/sbin/httpd 2>/dev/null || true
            fi

            if [[ "$original_www" != "exists" ]]; then
            rmdir /www 2>/dev/null || true
            fi

            if [[ "$original_jffs" != "exists" ]]; then
            rmdir /jffs 2>/dev/null || true
            fi
            }

            Before 'setup'
              After 'cleanup'

                It 'detects freshtomato platform'
              # Skip test on non-router systems
                  Skip if "Platform detection tests require router system" test -x "$(command -v wsl.exe 2>/dev/null)"

                  When call detect_platform
                  The output should equal 'freshtomato'
                End
              End
            End
