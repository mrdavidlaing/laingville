#!/usr/bin/env bash

Describe 'SBOM diff generator'
  Include bin/sbom-diff

  Describe 'extract_packages()'
    It 'extracts package name and version from SPDX JSON'
      When call extract_packages "$(
  cat << 'EOF'
{
  "packages": [
    {
      "name": "openssl",
      "version": "1.1.1",
      "SPDXID": "SPDXRef-Package-openssl-1.1.1"
    },
    {
      "name": "python",
      "version": "3.12.0",
      "SPDXID": "SPDXRef-Package-python-3.12.0"
    }
  ]
}
EOF
      )"
      The output should include 'openssl|1.1.1'
      The output should include 'python|3.12.0'
    End

    It 'handles empty package list'
      When call extract_packages "$(
  cat << 'EOF'
{
  "packages": []
}
EOF
      )"
      The output should equal ''
    End

    It 'handles single package'
      When call extract_packages "$(
  cat << 'EOF'
{
  "packages": [
    {
      "name": "curl",
      "version": "7.85.0",
      "SPDXID": "SPDXRef-Package-curl-7.85.0"
    }
  ]
}
EOF
      )"
      The output should equal 'curl|7.85.0'
    End
  End

  Describe 'find_added_packages()'
    setup() {
    before=$'openssl|1.1.1\npython|3.12.0'
    after=$'openssl|1.1.1\npython|3.12.0\ncurl|7.85.0\ngit|2.40.0'
    after_empty=$'openssl|1.1.1\npython|3.12.0'
    }
    Before 'setup'

      It 'identifies packages in after but not in before'
        When call find_added_packages "$before" "$after"
        The output should include 'curl|7.85.0'
        The output should include 'git|2.40.0'
        The output should not include 'openssl'
        The output should not include 'python'
      End

      It 'returns empty when no packages added'
        When call find_added_packages "$before" "$after_empty"
        The output should equal ''
      End

      It 'handles empty before list'
        When call find_added_packages "" "$before"
        The output should include 'openssl|1.1.1'
        The output should include 'python|3.12.0'
      End
    End

    Describe 'find_removed_packages()'
      setup() {
      before_with_vuln=$'openssl|1.1.1\nvulnerable-lib|0.9.0\npython|3.12.0'
      after_no_vuln=$'openssl|1.1.1\npython|3.12.0'
      before_same=$'openssl|1.1.1\npython|3.12.0'
      after_same=$'openssl|1.1.1\npython|3.12.0'
      }
      Before 'setup'

        It 'identifies packages in before but not in after (CVE fix scenario)'
          When call find_removed_packages "$before_with_vuln" "$after_no_vuln"
          The output should include 'vulnerable-lib|0.9.0'
          The output should not include 'openssl'
          The output should not include 'python'
        End

        It 'returns empty when no packages removed'
          When call find_removed_packages "$before_same" "$after_same"
          The output should equal ''
        End

        It 'handles empty after list'
          When call find_removed_packages "$before_same" ""
          The output should include 'openssl|1.1.1'
          The output should include 'python|3.12.0'
        End
      End

      Describe 'find_updated_packages()'
        setup() {
        before_updates=$'openssl|1.1.1\npython|3.12.0\ncurl|7.85.0'
        after_updates=$'openssl|1.1.2\npython|3.12.0\ncurl|7.86.0'
        before_no_updates=$'openssl|1.1.1\npython|3.12.0'
        after_no_updates=$'openssl|1.1.1\npython|3.12.0'
        }
        Before 'setup'

          It 'identifies packages with same name but different version'
            When call find_updated_packages "$before_updates" "$after_updates"
            The output should include 'openssl|1.1.1|1.1.2'
            The output should include 'curl|7.85.0|7.86.0'
            The output should not include 'python'
          End

          It 'returns empty when no packages updated'
            When call find_updated_packages "$before_no_updates" "$after_no_updates"
            The output should equal ''
          End

          It 'handles version with multiple dots'
            When call find_updated_packages "nodejs|18.12.1" "nodejs|18.13.0"
            The output should include 'nodejs|18.12.1|18.13.0'
          End
        End

        Describe 'generate_diff_json()'
          setup() {
          added_multi=$'curl|7.85.0\ngit|2.40.0'
          removed_single='vulnerable-lib|0.9.0'
          updated_single='openssl|1.1.1|1.1.2'
          added_single='curl|7.85.0'
          removed_multi=$'vulnerable-pkg|0.9.0\nanother-vuln|1.0.0'
          }
          Before 'setup'

            It 'generates valid JSON with all diff categories'
              When call generate_diff_json "$added_multi" "$removed_single" "$updated_single"
              The output should include '"added":'
              The output should include '"removed":'
              The output should include '"updated":'
              The output should include '"summary":'
              The output should include 'curl'
              The output should include 'git'
              The output should include 'vulnerable-lib'
              The output should include 'openssl'
            End

            It 'generates JSON with empty categories'
              When call generate_diff_json "" "" ""
              The output should include '"added": []'
              The output should include '"removed": []'
              The output should include '"updated": []'
            End

            It 'generates correct summary message'
              When call generate_diff_json "$added_single" "$removed_single" "$updated_single"
              The output should include '"summary":'
              The output should include 'Removed 1'
              The output should include 'updated 1'
              The output should include 'added 1'
            End

            It 'handles only removals (CVE fix)'
              When call generate_diff_json "" "$removed_multi" ""
              The output should include '"added": []'
              The output should include '"removed":'
              The output should include 'vulnerable-pkg'
              The output should include 'another-vuln'
              The output should include 'Removed 2'
            End
          End

          Describe 'main script'
            Context 'with valid SBOM files'
              setup() {
  # Create temporary test SBOM files
  cat > /tmp/before.json << 'EOF'
{
  "spdxVersion": "SPDX-2.3",
  "packages": [
    {
      "name": "openssl",
      "version": "1.1.1",
      "SPDXID": "SPDXRef-Package-openssl-1.1.1"
    },
    {
      "name": "vulnerable-lib",
      "version": "0.9.0",
      "SPDXID": "SPDXRef-Package-vulnerable-lib-0.9.0"
    },
    {
      "name": "python",
      "version": "3.12.0",
      "SPDXID": "SPDXRef-Package-python-3.12.0"
    }
  ]
}
EOF

  cat > /tmp/after.json << 'EOF'
{
  "spdxVersion": "SPDX-2.3",
  "packages": [
    {
      "name": "openssl",
      "version": "1.1.2",
      "SPDXID": "SPDXRef-Package-openssl-1.1.2"
    },
    {
      "name": "python",
      "version": "3.12.0",
      "SPDXID": "SPDXRef-Package-python-3.12.0"
    },
    {
      "name": "curl",
      "version": "7.85.0",
      "SPDXID": "SPDXRef-Package-curl-7.85.0"
    }
  ]
}
EOF
              }

              Before 'setup'

                It 'computes diff between two SBOM files'
                  When call main_sbom_diff /tmp/before.json /tmp/after.json
                  The status should be success
                  The output should include '"added":'
                  The output should include '"removed":'
                  The output should include '"updated":'
                  The output should include 'curl'
                  The output should include 'vulnerable-lib'
                  The output should include 'openssl'
                End

                It 'identifies removed vulnerable package'
                  When call main_sbom_diff /tmp/before.json /tmp/after.json
                  The output should include 'vulnerable-lib'
                  The output should include '0.9.0'
                End

                It 'identifies updated package'
                  When call main_sbom_diff /tmp/before.json /tmp/after.json
                  The output should include 'openssl'
                  The output should include '1.1.1'
                  The output should include '1.1.2'
                End

                It 'identifies added package'
                  When call main_sbom_diff /tmp/before.json /tmp/after.json
                  The output should include 'curl'
                  The output should include '7.85.0'
                End
              End

              Context 'with missing arguments'
                It 'exits with error when no arguments provided'
                  When call main_sbom_diff
                  The status should be failure
                  The stderr should include 'Usage:'
                End

                It 'exits with error when only one argument provided'
                  When call main_sbom_diff /tmp/before.json
                  The status should be failure
                  The stderr should include 'Usage:'
                End
              End

              Context 'with missing files'
                It 'exits with error when before file does not exist'
                  When call main_sbom_diff /nonexistent/before.json /tmp/after.json
                  The status should be failure
                  The stderr should include 'Error:'
                End

                It 'exits with error when after file does not exist'
                  When call main_sbom_diff /tmp/before.json /nonexistent/after.json
                  The status should be failure
                  The stderr should include 'Error:'
                End
              End

              Context 'with invalid JSON'
                setup() {
                echo 'invalid json' > /tmp/invalid.json
                }

                Before 'setup'

                  It 'exits with error on invalid JSON in before file'
                    When call main_sbom_diff /tmp/invalid.json /tmp/after.json
                    The status should be failure
                    The stderr should include 'Error:'
                  End
                End
              End
            End
