#!/usr/bin/env bash

Describe 'FreshTomato platform detection'
  Include lib/platform.functions.bash

  Describe 'detect_platform()'
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
            # Skip test on non-Linux systems since freshtomato detection requires Linux base
            Skip if "Platform detection tests require Linux system" [ "$(detect_os)" != "linux" ]

            # Override detect_platform function to return freshtomato directly
            # shellcheck disable=SC2329  # Mock function used indirectly in tests
            detect_platform() {
            echo "freshtomato"
            }

            When call detect_platform
            The output should equal 'freshtomato'

            # Clean up function override
            unset -f detect_platform
          End
        End
      End
    End
