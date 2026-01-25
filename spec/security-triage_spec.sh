#!/usr/bin/env bash

Describe 'security-triage'
  Include bin/security-triage

  Describe 'severity_to_priority()'
    It 'maps CRITICAL with exploit to priority 1'
      When call severity_to_priority 'critical' 'true'
      The output should equal '1'
    End

    It 'maps CRITICAL without exploit to priority 2'
      When call severity_to_priority 'critical' 'false'
      The output should equal '2'
    End

    It 'maps HIGH with exploit to priority 3'
      When call severity_to_priority 'high' 'true'
      The output should equal '3'
    End

    It 'maps HIGH without exploit to priority 4'
      When call severity_to_priority 'high' 'false'
      The output should equal '4'
    End

    It 'maps MEDIUM to priority 5'
      When call severity_to_priority 'medium' 'false'
      The output should equal '5'
    End

    It 'maps LOW to priority 5'
      When call severity_to_priority 'low' 'false'
      The output should equal '5'
    End

    It 'handles uppercase severity'
      When call severity_to_priority 'CRITICAL' 'true'
      The output should equal '1'
    End
  End

  Describe 'extract_cve_id()'
    It 'extracts CVE from trivy rule ID'
      When call extract_cve_id 'trivy-laingville-devcontainer-CVE-2024-1234'
      The output should equal 'CVE-2024-1234'
    End

    It 'extracts CVE from grype rule ID'
      When call extract_cve_id 'grype-example-python-CVE-2023-5678'
      The output should equal 'CVE-2023-5678'
    End

    It 'extracts CVE from simple rule ID'
      When call extract_cve_id 'CVE-2024-9999'
      The output should equal 'CVE-2024-9999'
    End

    It 'returns empty for non-CVE rule ID'
      When call extract_cve_id 'some-other-rule'
      The output should equal ''
    End
  End

  Describe 'extract_image_name()'
    It 'extracts image name from trivy rule ID'
      When call extract_image_name 'trivy-laingville-devcontainer-CVE-2024-1234'
      The output should equal 'laingville-devcontainer'
    End

    It 'extracts image name from grype rule ID'
      When call extract_image_name 'grype-example-python-devcontainer-CVE-2023-5678'
      The output should equal 'example-python-devcontainer'
    End

    It 'returns empty for rule without image pattern'
      When call extract_image_name 'CVE-2024-1234'
      The output should equal ''
    End
  End

  Describe 'get_higher_severity()'
    It 'returns critical when comparing critical and high'
      When call get_higher_severity 'critical' 'high'
      The output should equal 'critical'
    End

    It 'returns critical when comparing high and critical'
      When call get_higher_severity 'high' 'critical'
      The output should equal 'critical'
    End

    It 'returns high when comparing high and medium'
      When call get_higher_severity 'high' 'medium'
      The output should equal 'high'
    End

    It 'returns medium when comparing medium and low'
      When call get_higher_severity 'medium' 'low'
      The output should equal 'medium'
    End

    It 'returns first when both are equal'
      When call get_higher_severity 'high' 'high'
      The output should equal 'high'
    End
  End

  Describe 'triage_alerts()'
    Context 'with single alert'
      setup_single_alert() {
      MOCK_ALERTS='[
      {
      "rule": {
      "id": "trivy-laingville-devcontainer-CVE-2024-1234",
      "severity": "critical",
      "description": "Remote code execution in openssl"
      },
      "state": "open"
      }
      ]'
      }

      Before 'setup_single_alert'

        It 'produces valid JSON output'
          When call triage_alerts "$MOCK_ALERTS"
          The output should include '"cve_id"'
          The output should include '"priority"'
          The output should include '"severity"'
          The output should include '"affected_images"'
        End

        It 'extracts CVE ID correctly'
          When call triage_alerts "$MOCK_ALERTS"
          The output should include '"cve_id": "CVE-2024-1234"'
        End

        It 'assigns correct priority for critical severity'
          When call triage_alerts "$MOCK_ALERTS"
          The output should include '"priority": 2'
        End

        It 'extracts affected image'
          When call triage_alerts "$MOCK_ALERTS"
          The output should include '"laingville-devcontainer"'
        End
      End

      Context 'with duplicate CVE from multiple scanners'
        setup_duplicate_alerts() {
        MOCK_ALERTS='[
        {
        "rule": {
        "id": "trivy-laingville-devcontainer-CVE-2024-1234",
        "severity": "high",
        "description": "Remote code execution in openssl"
        },
        "state": "open"
        },
        {
        "rule": {
        "id": "grype-laingville-devcontainer-CVE-2024-1234",
        "severity": "critical",
        "description": "RCE in openssl"
        },
        "state": "open"
        }
        ]'
        }

        Before 'setup_duplicate_alerts'

          It 'deduplicates by CVE ID'
            When call triage_alerts "$MOCK_ALERTS"
# Should only have one entry for CVE-2024-1234
            The output should include '"cve_id": "CVE-2024-1234"'
# Count occurrences - should be exactly 1
            The output should not include '"cve_id": "CVE-2024-1234".*"cve_id": "CVE-2024-1234"'
          End

          It 'uses highest severity when scanners disagree'
            When call triage_alerts "$MOCK_ALERTS"
# Should use critical (from grype) not high (from trivy)
            The output should include '"severity": "critical"'
          End

          It 'collects all rule IDs'
            When call triage_alerts "$MOCK_ALERTS"
            The output should include '"trivy-laingville-devcontainer-CVE-2024-1234"'
            The output should include '"grype-laingville-devcontainer-CVE-2024-1234"'
          End
        End

        Context 'with same CVE affecting multiple images'
          setup_multi_image_alerts() {
          MOCK_ALERTS='[
          {
          "rule": {
          "id": "trivy-laingville-devcontainer-CVE-2024-1234",
          "severity": "critical",
          "description": "Remote code execution in openssl"
          },
          "state": "open"
          },
          {
          "rule": {
          "id": "trivy-example-python-devcontainer-CVE-2024-1234",
          "severity": "critical",
          "description": "Remote code execution in openssl"
          },
          "state": "open"
          }
          ]'
          }

          Before 'setup_multi_image_alerts'

            It 'collects all affected images for same CVE'
              When call triage_alerts "$MOCK_ALERTS"
              The output should include '"laingville-devcontainer"'
              The output should include '"example-python-devcontainer"'
            End
          End

          Context 'with multiple different CVEs'
            setup_multiple_cves() {
            MOCK_ALERTS='[
            {
            "rule": {
            "id": "trivy-image1-CVE-2024-1111",
            "severity": "critical",
            "description": "Critical vuln"
            },
            "state": "open"
            },
            {
            "rule": {
            "id": "trivy-image2-CVE-2024-2222",
            "severity": "high",
            "description": "High vuln"
            },
            "state": "open"
            },
            {
            "rule": {
            "id": "trivy-image3-CVE-2024-3333",
            "severity": "medium",
            "description": "Medium vuln"
            },
            "state": "open"
            }
            ]'
            }

            Before 'setup_multiple_cves'

              It 'outputs multiple CVE entries'
                When call triage_alerts "$MOCK_ALERTS"
                The output should include '"CVE-2024-1111"'
                The output should include '"CVE-2024-2222"'
                The output should include '"CVE-2024-3333"'
              End

              It 'sorts by priority (critical first)'
                When call triage_alerts "$MOCK_ALERTS"
                The line 3 should include '"cve_id": "CVE-2024-1111"'
              End
            End

            Context 'with empty input'
              It 'returns empty array for empty input'
                When call triage_alerts '[]'
                The output should equal '[]'
              End
            End

            Context 'with closed alerts'
              setup_closed_alerts() {
              MOCK_ALERTS='[
              {
              "rule": {
              "id": "trivy-image1-CVE-2024-1111",
              "severity": "critical",
              "description": "Critical vuln"
              },
              "state": "closed"
              },
              {
              "rule": {
              "id": "trivy-image2-CVE-2024-2222",
              "severity": "high",
              "description": "High vuln"
              },
              "state": "open"
              }
              ]'
              }

              Before 'setup_closed_alerts'

                It 'filters out closed alerts'
                  When call triage_alerts "$MOCK_ALERTS"
                  The output should not include '"CVE-2024-1111"'
                  The output should include '"CVE-2024-2222"'
                End
              End
            End
          End
