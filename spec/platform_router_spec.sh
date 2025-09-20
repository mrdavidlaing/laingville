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
        # Skip test on non-router systems
            Skip if "Platform detection tests require router system" test -x "$(command -v wsl.exe 2>/dev/null)"

            When call detect_platform
            The output should equal 'freshtomato'
          End
        End
      End
    End
