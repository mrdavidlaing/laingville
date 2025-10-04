#!/opt/bin/bash
# Parse the server inventory table from servers/README.md
# Supports test mode for validation and extraction in different formats

set -euo pipefail

parse_server_table() {
  local format="${1:-full}"
  local readme="${2:-/tmp/mnt/dwaca-usb/laingville/servers/README.md}"

  # Validate input file exists
  if [ ! -f "$readme" ]; then
    echo "Error: README file not found at $readme" >&2
    return 1
  fi

  # Extract table rows with DHCP (Reserved), skip empty fields
  grep -E '^\|.*\|.*DHCP \(Reserved\).*\|' "$readme" | while IFS='|' read -r _ name hostname _ ip mac _ _; do
    # Trim whitespace (avoid xargs which may not be available on FreshTomato)
    hostname=$(echo "$hostname" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    ip=$(echo "$ip" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    mac=$(echo "$mac" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip entries with missing critical data
    if [ -z "$hostname" ] || [ -z "$ip" ] || [ -z "$mac" ]; then
      echo "Warning: Skipping incomplete entry: hostname='$hostname' ip='$ip' mac='$mac'" >&2
      continue
    fi

    # Validate IP format (basic check)
    if ! echo "$ip" | grep -E '^192\.168\.[0-9]+\.[0-9]+$' > /dev/null; then
      echo "Warning: Invalid IP format '$ip' for host '$hostname'" >&2
      continue
    fi

    # Validate MAC format (basic check: XX:XX:XX:XX:XX:XX)
    if ! echo "$mac" | grep -E '^[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}$' > /dev/null; then
      echo "Warning: Invalid MAC format '$mac' for host '$hostname'" >&2
      continue
    fi

    case "$format" in
      dhcp)
        echo "${mac}<${ip}<${hostname}<0"
        ;;
      hosts)
        echo "${ip} ${hostname}.laingville.internal ${hostname}"
        ;;
      full)
        echo "${hostname}:${mac}:${ip}"
        ;;
      *)
        echo "Error: Unknown format '$format'. Use: dhcp, hosts, or full" >&2
        return 1
        ;;
    esac
  done
}

# Test mode - validates parsing with comprehensive test cases
if [ "${1:-}" = "--test" ]; then
  echo "Testing parse_server_table function..."

  # Create comprehensive test README content
  cat > /tmp/test_readme.md << 'EOF'
# Servers

## Server Inventory

| Server Name | Hostname | IP Discovery | IP Address | MAC Address | Services | Notes |
|-------------|----------|--------------|------------|-------------|----------|-------|
| [dwaca](./dwaca/) | dwaca | Static (Router) | 192.168.1.2 | N/A | DNS, DHCP, WiFi | FreshTomato router |
| [baljeet](./baljeet/) | baljeet | DHCP (Reserved) | 192.168.1.77 | 60:03:08:8A:99:36 | General purpose | Former DNS server |
| [phineas](./phineas/) | phineas | DHCP (Reserved) | 192.168.1.70 | C8:69:CD:AA:4E:0A | TBD | TBD |
| [ferb](./ferb/) | ferb | DHCP (Reserved) | 192.168.1.67 | 80:E6:50:24:50:78 | TBD | TBD |
| [monogram](./monogram/) | monogram | DHCP (Reserved) | 192.168.1.26 | FC:34:97:BA:A9:06 | TBD | TBD |
| [badip](./badip/) | badip | DHCP (Reserved) | 10.0.0.1 | AA:BB:CC:DD:EE:FF | Test | Invalid IP |
| [badmac](./badmac/) | badmac | DHCP (Reserved) | 192.168.1.99 | invalid-mac | Test | Invalid MAC |
| [incomplete](./incomplete/) | incomplete | DHCP (Reserved) |  | 11:22:33:44:55:66 | Test | Missing IP |
EOF

  echo ""
  echo "Test 1: DHCP format parsing"
  result=$(parse_server_table dhcp /tmp/test_readme.md 2> /dev/null)
  expected_count=$(echo "$result" | wc -l)
  if [ "$expected_count" -eq 4 ] && echo "$result" | grep -q "60:03:08:8A:99:36<192.168.1.77<baljeet"; then
    echo "  ✓ DHCP format parsing works correctly (4 valid entries)"
  else
    echo "  ✗ DHCP format failed. Expected 4 entries, got $expected_count"
    echo "    Result: $result"
  fi

  echo ""
  echo "Test 2: Hosts format parsing"
  result=$(parse_server_table hosts /tmp/test_readme.md 2> /dev/null)
  if echo "$result" | grep -q "192.168.1.77 baljeet.laingville.internal baljeet"; then
    echo "  ✓ Hosts format parsing works correctly"
  else
    echo "  ✗ Hosts format failed"
    echo "    Result: $result"
  fi

  echo ""
  echo "Test 3: Excludes non-DHCP entries"
  result=$(parse_server_table full /tmp/test_readme.md 2> /dev/null)
  if ! echo "$result" | grep -q "dwaca" && echo "$result" | grep -q "baljeet"; then
    echo "  ✓ Correctly excludes Static (Router) entries"
  else
    echo "  ✗ Failed to exclude non-DHCP entries"
    echo "    Result: $result"
  fi

  echo ""
  echo "Test 4: Validation and error handling"
  result=$(parse_server_table dhcp /tmp/test_readme.md 2>&1)
  warning_count=$(echo "$result" | grep -c "Warning:" || true)
  if [ "$warning_count" -ge 3 ]; then
    echo "  ✓ Validation correctly identifies invalid entries ($warning_count warnings)"
  else
    echo "  ✗ Validation failed. Expected 3+ warnings, got $warning_count"
    echo "    Output: $result"
  fi

  echo ""
  echo "Test 5: Error handling for missing file"
  parse_server_table dhcp /nonexistent/file.md 2> /dev/null
  if [ $? -eq 0 ]; then
    echo "  ✗ Should have failed for missing file"
  else
    echo "  ✓ Correctly handles missing file"
  fi

  echo ""
  echo "Test 6: Invalid format parameter"
  parse_server_table invalid_format /tmp/test_readme.md 2> /dev/null
  if [ $? -eq 0 ]; then
    echo "  ✗ Should have failed for invalid format"
  else
    echo "  ✓ Correctly rejects invalid format"
  fi

  # Cleanup
  rm -f /tmp/test_readme.md
  echo ""
  echo "All tests completed!"
  exit 0
fi

# If called directly (not sourced) with arguments, execute the function
if [ -n "${1:-}" ] && [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  parse_server_table "$@"
fi
