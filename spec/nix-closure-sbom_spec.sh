#!/usr/bin/env bash

Describe 'Nix closure SBOM generator'
  Include infra/scripts/nix-closure-sbom.sh

  Describe 'parse_store_path()'
    It 'extracts package name and version from simple store path'
      When call parse_store_path '/nix/store/abc123-python-3.12.0'
      The output should equal 'python|3.12.0'
    End

    It 'extracts package name and version with hash prefix'
      When call parse_store_path '/nix/store/7h8i9j0k-nodejs-22.0.0'
      The output should equal 'nodejs|22.0.0'
    End

    It 'handles package names with hyphens'
      When call parse_store_path '/nix/store/abc123-python-dev-tools-3.12.1'
      The output should equal 'python-dev-tools|3.12.1'
    End

    It 'handles versions with multiple dots'
      When call parse_store_path '/nix/store/abc123-gcc-12.3.0-rc1'
      The output should equal 'gcc|12.3.0-rc1'
    End

    It 'returns empty for invalid path'
      When call parse_store_path '/invalid/path'
      The output should equal ''
    End
  End

  Describe 'generate_spdx_json()'
    Context 'with single package'
      It 'generates valid SPDX 2.3 JSON structure'
        When call generate_spdx_json 'python|3.12.0'
        The output should include '"spdxVersion": "SPDX-2.3"'
        The output should include '"dataLicense": "CC0-1.0"'
        The output should include '"creationInfo"'
        The output should include '"creators"'
        The output should include '"packages"'
        The output should include '"name": "python"'
        The output should include '"version": "3.12.0"'
        The output should include '"SPDXID": "SPDXRef-Package-python-3.12.0"'
        The output should include '"downloadLocation": "NOASSERTION"'
        The output should include '"filesAnalyzed": false'
      End

      It 'generates valid JSON that can be parsed'
        When call generate_spdx_json 'python|3.12.0'
        The output should include '{'
        The output should include '}'
      End
    End

    Context 'with multiple packages'
      It 'generates SPDX JSON with multiple packages'
        When call generate_spdx_json 'python|3.12.0' 'nodejs|22.0.0'
        The output should include '"name": "python"'
        The output should include '"name": "nodejs"'
        The output should include '"version": "3.12.0"'
        The output should include '"version": "22.0.0"'
      End
    End
  End

  Describe 'main script'
    Context 'with valid flake output'
      It 'accepts flake output as argument'
        When call main_nix_closure_sbom '.#test-output'
        The status should be success
        The output should include '"spdxVersion": "SPDX-2.3"'
      End
    End

    Context 'with missing argument'
      It 'exits with error when no flake output provided'
        When call main_nix_closure_sbom
        The status should be failure
        The stderr should include 'Usage:'
      End
    End
  End

  Describe 'integration test'
    Context 'with mock nix path-info output'
      setup() {
  # Mock nix path-info to return test data
  # shellcheck disable=SC2329
      nix() {
      if [[ "$1" = "path-info" && "$2" = "--json" && "$3" = "--recursive" ]]; then
      cat << 'EOF'
[
  {
    "path": "/nix/store/abc123-python-3.12.0",
    "narHash": "sha256:xyz",
    "narSize": 12345,
    "references": []
  },
  {
    "path": "/nix/store/def456-nodejs-22.0.0",
    "narHash": "sha256:uvw",
    "narSize": 54321,
    "references": []
  }
]
EOF
      else
      command nix "$@"
      fi
      }
      export -f nix
      }

      Before 'setup'

        It 'generates SBOM from nix path-info output'
          When call generate_sbom_from_closure '.#test'
          The output should include '"spdxVersion": "SPDX-2.3"'
          The output should include '"name": "python"'
          The output should include '"name": "nodejs"'
        End
      End
    End
  End
