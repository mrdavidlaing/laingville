#!/usr/bin/env bash

Describe 'parse_server_inventory.bash'
  Include servers/dwaca/scripts/parse_server_inventory.bash

  setup() {
    cat > /tmp/test_servers_readme.md << 'EOF'
# Servers

## Network Topology

```
Home Network: 192.168.1.0/24
Gateway: 192.168.1.1 (Vodafone Fibre Modem/Router)
DNS: 192.168.1.2 (dwaca - FreshTomato dnsmasq server)
```

## Server Inventory

| Server Name | Hostname | IP Discovery | IP Address | MAC Address | Services | Notes |
|-------------|----------|--------------|------------|-------------|----------|-------|
| [dwaca](./dwaca/) | dwaca | Static (Router) | 192.168.1.2 | N/A | DNS, DHCP, WiFi | FreshTomato router, primary DNS/DHCP server |
| [baljeet](./baljeet/) | baljeet | DHCP (Reserved) | 192.168.1.77 | 60:03:08:8A:99:36 | General purpose | Former DNS server |
| [phineas](./phineas/) | phineas | DHCP (Reserved) | 192.168.1.70 | C8:69:CD:AA:4E:0A | TBD | TBD |
| [ferb](./ferb/) | ferb | DHCP (Reserved) | 192.168.1.67 | 80:E6:50:24:50:78 | TBD | TBD |
| [monogram](./monogram/) | monogram | DHCP (Reserved) | 192.168.1.26 | FC:34:97:BA:A9:06 | TBD | TBD |
EOF
  }

  cleanup() {
    rm -f /tmp/test_servers_readme.md
  }

  BeforeEach 'setup'
  AfterEach 'cleanup'

  Describe 'parse_server_table dhcp'
    It 'extracts MAC to IP mappings in DHCP format'
      When call parse_server_table dhcp /tmp/test_servers_readme.md
      The output should include "60:03:08:8A:99:36<192.168.1.77<baljeet"
      The output should include "C8:69:CD:AA:4E:0A<192.168.1.70<phineas"
      The output should include "80:E6:50:24:50:78<192.168.1.67<ferb"
      The output should include "FC:34:97:BA:A9:06<192.168.1.26<monogram"
      The lines of output should equal 4
    End

    It 'excludes the router entry'
      When call parse_server_table dhcp /tmp/test_servers_readme.md
      The output should not include "dwaca"
      The output should not include "N/A"
    End
  End

  Describe 'parse_server_table hosts'
    It 'generates hosts file entries with FQDN and short name'
      When call parse_server_table hosts /tmp/test_servers_readme.md
      The output should include "192.168.1.77 baljeet.laingville.internal baljeet"
      The output should include "192.168.1.70 phineas.laingville.internal phineas"
      The output should include "192.168.1.67 ferb.laingville.internal ferb"
      The output should include "192.168.1.26 monogram.laingville.internal monogram"
      The lines of output should equal 4
    End

    It 'excludes router from hosts output'
      When call parse_server_table hosts /tmp/test_servers_readme.md
      The output should not include "dwaca.laingville.internal"
    End
  End

  Describe 'parse_server_table full'
    It 'outputs full server information in colon-separated format'
      When call parse_server_table full /tmp/test_servers_readme.md
      The output should include "baljeet:60:03:08:8A:99:36:192.168.1.77"
      The output should include "phineas:C8:69:CD:AA:4E:0A:192.168.1.70"
      The output should include "ferb:80:E6:50:24:50:78:192.168.1.67"
      The output should include "monogram:FC:34:97:BA:A9:06:192.168.1.26"
      The lines of output should equal 4
    End
  End

  Describe 'input validation'
    It 'handles missing file gracefully'
      When call parse_server_table dhcp /tmp/nonexistent_file.md
      The status should be failure
      The stderr should include "README file not found"
    End

    It 'rejects invalid format parameter'
      When call parse_server_table invalid_format /tmp/test_servers_readme.md
      The status should be failure
      The stderr should include "Unknown format"
    End
  End

  Describe 'edge cases with malformed data'
    setup_malformed() {
      cat > /tmp/malformed_servers.md << 'EOF'
| Server Name | Hostname | IP Discovery | IP Address | MAC Address | Services | Notes |
|-------------|----------|--------------|------------|-------------|----------|-------|
| [test1](./test1/) | test1 | DHCP (Reserved) | 192.168.1.99 | AA:BB:CC:DD:EE:FF | Test | Valid entry |
| [test2](./test2/) | test2 | DHCP (Reserved) | 10.0.0.1 | 11:22:33:44:55:66 | Test | Invalid IP range |
| [test3](./test3/) | test3 | DHCP (Reserved) | not-an-ip | 22:33:44:55:66:77 | Test | Invalid IP format |
| [test4](./test4/) | test4 | DHCP (Reserved) | 192.168.1.98 | invalid-mac | Test | Invalid MAC |
| [test5](./test5/) | test5 | DHCP (Reserved) | 192.168.1.97 | AA:BB:CC:DD:EE | Test | Short MAC |
| [test6](./test6/) |  | DHCP (Reserved) | 192.168.1.96 | 11:22:33:44:55:66 | Test | Missing hostname |
| [test7](./test7/) | test7 | DHCP (Reserved) |  | 22:33:44:55:66:77 | Test | Missing IP |
| [test8](./test8/) | test8 | DHCP (Reserved) | 192.168.1.95 |  | Test | Missing MAC |
EOF
    }

    cleanup_malformed() {
      rm -f /tmp/malformed_servers.md
    }

    BeforeEach 'setup_malformed'
    AfterEach 'cleanup_malformed'

    It 'validates IP address format and excludes invalid IPs'
      When call parse_server_table dhcp /tmp/malformed_servers.md
      The output should include "AA:BB:CC:DD:EE:FF<192.168.1.99<test1"
      The output should not include "10.0.0.1"
      The output should not include "not-an-ip"
      The stderr should include "Invalid IP format"
    End

    It 'validates MAC address format and excludes invalid MACs'
      When call parse_server_table dhcp /tmp/malformed_servers.md
      The output should include "AA:BB:CC:DD:EE:FF<192.168.1.99<test1"
      The output should not include "invalid-mac"
      The output should not include "192.168.1.97"
      The stderr should include "Invalid MAC format"
    End

    It 'skips entries with missing required data'
      When call parse_server_table dhcp /tmp/malformed_servers.md
      The output should include "AA:BB:CC:DD:EE:FF<192.168.1.99<test1"
      The lines of output should equal 1
      The stderr should include "Skipping incomplete entry"
    End
  End

  Describe 'whitespace handling'
    setup_whitespace() {
      cat > /tmp/whitespace_servers.md << 'EOF'
| Server Name | Hostname | IP Discovery | IP Address | MAC Address | Services | Notes |
|-------------|----------|--------------|------------|-------------|----------|-------|
| [test1](./test1/) |   test1   | DHCP (Reserved) |   192.168.1.99   |   AA:BB:CC:DD:EE:FF   | Test | Whitespace test |
EOF
    }

    cleanup_whitespace() {
      rm -f /tmp/whitespace_servers.md
    }

    BeforeEach 'setup_whitespace'
    AfterEach 'cleanup_whitespace'

    It 'handles whitespace in table cells correctly'
      When call parse_server_table dhcp /tmp/whitespace_servers.md
      The output should include "AA:BB:CC:DD:EE:FF<192.168.1.99<test1"
      The output should not include "   test1   "
      The output should not include "   192.168.1.99   "
    End
  End
End
