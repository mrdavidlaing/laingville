#!/bin/bash
# Analyze banned IPs and patterns for Minecraft server security
# Shows what fail2ban has learned and suggests improvements

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_section() { echo -e "${BLUE}=== $1 ===${NC}"; }

# Get geographic info for IP
get_geo_info() {
  local ip="$1"
  if command -v geoiplookup > /dev/null 2>&1; then
    timeout 2s geoiplookup "$ip" 2> /dev/null | head -1 | cut -d' ' -f4- | sed 's/^, //' || echo "Unknown"
  else
    echo "GeoIP not available"
  fi
}

# Analyze current fail2ban status
analyze_fail2ban_status() {
  log_section "fail2ban Status Analysis"

  local jails=("minecraft-scanner" "minecraft-flood" "minecraft-repeat-offender")

  for jail in "${jails[@]}"; do
    echo ""
    echo -e "${PURPLE}$jail jail:${NC}"

    if sudo fail2ban-client status "$jail" > /dev/null 2>&1; then
      local status=$(sudo fail2ban-client status "$jail")
      local currently_banned_count=$(echo "$status" | grep "Currently banned:" | cut -d: -f2 | xargs)
      local total_banned=$(echo "$status" | grep "Total banned:" | cut -d: -f2 | xargs)
      local banned_ip_list=$(echo "$status" | grep "Banned IP list:" | cut -d: -f2 | xargs)

      echo "  Currently banned: ${currently_banned_count:-0} IPs"
      echo "  Total banned: ${total_banned:-0} IPs"

      if [[ -n "$banned_ip_list" && "$banned_ip_list" != "" ]]; then
        echo "  Banned IPs:"
        for ip in $banned_ip_list; do
          local geo=$(get_geo_info "$ip")
          printf "    %-15s - %s\n" "$ip" "$geo"
        done
      fi
    else
      echo "  Status: Not active"
    fi
  done
}

# Analyze IP patterns in logs
analyze_log_patterns() {
  log_section "Recent Attack Pattern Analysis"

  local temp_dir="/tmp/minecraft_analysis_$$"
  mkdir -p "$temp_dir"

  # Extract recent Minecraft-related logs from systemd journal (last 24 hours)
  sudo journalctl --since="24 hours ago" | grep "MINECRAFT" > "$temp_dir/recent_minecraft_logs.txt" 2> /dev/null || touch "$temp_dir/recent_minecraft_logs.txt"

  local total_attempts=$(wc -l < "$temp_dir/recent_minecraft_logs.txt")
  echo "Total connection attempts (24h): $total_attempts"

  if [[ $total_attempts -eq 0 ]]; then
    echo "No recent Minecraft connection attempts found in logs"
    rm -rf "$temp_dir"
    return
  fi

  # Extract IPs and count attempts
  grep -o 'SRC=[0-9.]*' "$temp_dir/recent_minecraft_logs.txt" \
    | cut -d'=' -f2 | sort | uniq -c | sort -nr > "$temp_dir/ip_counts.txt"

  echo ""
  echo -e "${PURPLE}Top 10 Most Active IPs (24h):${NC}"
  if [[ -s "$temp_dir/ip_counts.txt" ]]; then
    head -10 "$temp_dir/ip_counts.txt" | while read -r count ip; do
      local geo=$(get_geo_info "$ip")
      local is_local=""
      if echo "$ip" | grep -qE "(192\.168\.|10\.|127\.|172\.(1[6-9]|2[0-9]|3[01])\.)"; then
        is_local="[LOCAL]"
      fi
      printf "  %-15s %4d attempts - %s %s\n" "$ip" "$count" "$geo" "$is_local"
    done
  else
    echo "  No connection patterns found"
  fi

  # Analyze geographic distribution
  echo ""
  echo -e "${PURPLE}Geographic Distribution:${NC}"
  if [[ -s "$temp_dir/ip_counts.txt" ]]; then
    tail -n +2 "$temp_dir/ip_counts.txt" | while read -r count ip; do
      # Skip local IPs for geo analysis
      if ! echo "$ip" | grep -qE "(192\.168\.|10\.|127\.|172\.(1[6-9]|2[0-9]|3[01])\.)"; then
        local geo=$(get_geo_info "$ip")
        echo "$geo"
      fi
    done | sort | uniq -c | sort -nr > "$temp_dir/geo_counts.txt"

    if [[ -s "$temp_dir/geo_counts.txt" ]]; then
      head -10 "$temp_dir/geo_counts.txt" | while read -r count country; do
        printf "  %-20s %d unique IPs\n" "$country" "$count"
      done
    else
      echo "  No geographic data available"
    fi
  else
    echo "  No data to analyze"
  fi

  # Check for subnet patterns
  echo ""
  echo -e "${PURPLE}Subnet Analysis (potential botnets):${NC}"
  if [[ -s "$temp_dir/ip_counts.txt" ]]; then
    tail -n +2 "$temp_dir/ip_counts.txt" | while read -r count ip; do
      # Extract /24 subnet
      echo "$ip" | cut -d. -f1-3
    done | sort | uniq -c | sort -nr | head -10 | while read -r count subnet; do
      if [[ $count -gt 1 ]]; then
        printf "  %s.0/24: %d IPs (potential botnet)\n" "$subnet" "$count"
      fi
    done
  else
    echo "  No subnet analysis possible"
  fi

  rm -rf "$temp_dir"
}

# Analyze blocked vs accepted traffic
analyze_effectiveness() {
  log_section "Security Effectiveness Analysis"

  # Count different types of log entries from systemd journal
  local temp_log="/tmp/minecraft_effectiveness_$$"
  sudo journalctl --since="24 hours ago" > "$temp_log" 2> /dev/null

  # Use grep and wc to avoid grep -c exit status issues
  local total_attempts=$(grep "MINECRAFT" "$temp_log" 2> /dev/null | wc -l)
  local blocked=$(grep "MC-BLOCKED" "$temp_log" 2> /dev/null | wc -l)
  local rate_limited=$(grep "MC-RATE-LIMITED" "$temp_log" 2> /dev/null | wc -l)
  local temp_blocked=$(grep "MC-TEMP-BLOCKED" "$temp_log" 2> /dev/null | wc -l)

  echo "Connection attempts (24h): $total_attempts"
  echo "Blocked by rules: $blocked"
  echo "Rate limited: $rate_limited"
  echo "Temp blocked (scanners): $temp_blocked"

  if [[ $total_attempts -gt 0 ]]; then
    # Clean up any newlines in the numbers
    total_attempts=${total_attempts//[^0-9]/}
    blocked=${blocked//[^0-9]/}
    rate_limited=${rate_limited//[^0-9]/}
    temp_blocked=${temp_blocked//[^0-9]/}

    local blocked_percent=$(((blocked + rate_limited + temp_blocked) * 100 / total_attempts))
    echo "Protection rate: ${blocked_percent}%"
  fi

  # Clean up temp file
  rm -f "$temp_log"
}

# Show IP set statistics
analyze_ipsets() {
  log_section "IP Set Statistics"

  local sets=("ireland_ips" "temp_scanners")

  for set_name in "${sets[@]}"; do
    if sudo ipset list "$set_name" > /dev/null 2>&1; then
      local count=$(sudo ipset list "$set_name" | grep "^[0-9]" | wc -l 2> /dev/null)
      echo "$set_name: $count entries"

      # Clean count variable
      count=${count//[^0-9]/}
      if [[ "$set_name" == "temp_scanners" && $count -gt 0 ]]; then
        echo "  Currently blocked scanner IPs:"
        sudo ipset list "$set_name" | grep "^[0-9]" | while read -r ip _; do
          local geo=$(get_geo_info "$ip")
          printf "    %-15s - %s\n" "$ip" "$geo"
        done
      elif [[ "$set_name" == "ireland_ips" ]]; then
        echo "  Sample Irish IP ranges:"
        # Fix hanging pipe issue - use process substitution to avoid SIGPIPE
        while IFS= read -r line; do
          echo "    $line"
        done < <(sudo ipset list "$set_name" | grep "^[0-9]" | head -3)

        # Check if our current public IP is in the Irish allowlist
        echo ""
        echo "Checking current public IP allowlist status:"
        local current_ip
        current_ip=$(curl -s --connect-timeout 5 --max-time 10 icanhazip.com 2> /dev/null || echo "")
        if [[ -n "$current_ip" && "$current_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          echo "  Current public IP: $current_ip"
          if sudo ipset test ireland_ips "$current_ip" > /dev/null 2>&1; then
            echo "  ✅ Current IP is in Irish allowlist (will get preferential treatment)"
          else
            echo "  ⚠ Current IP is NOT in Irish allowlist"
          fi
        else
          echo "  ⚠ Could not determine current public IP"
        fi
      fi
    else
      echo "$set_name: Not found"
    fi
  done
}

# Check if current public IP is in Irish allowlist
check_current_ip_allowlisted() {
  echo "Checking current public IP allowlist status:"

  # Get our current public IP
  local current_ip=$(curl -s --connect-timeout 5 --max-time 10 icanhazip.com 2> /dev/null)

  if [[ -z "$current_ip" ]]; then
    echo "  ⚠ Could not determine current public IP"
    return
  fi

  # Validate IP format
  if [[ ! "$current_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "  ⚠ Invalid IP format received: $current_ip"
    return
  fi

  echo "  Current public IP: $current_ip"

  # Check if IP is in Irish allowlist
  if sudo ipset test ireland_ips "$current_ip" > /dev/null 2>&1; then
    echo "  ✅ Current IP is in Irish allowlist (will get preferential treatment)"
    local geo=$(get_geo_info "$current_ip")
    echo "  📍 Location: $geo"
  else
    echo "  ⚠ Current IP is NOT in Irish allowlist"
    local geo=$(get_geo_info "$current_ip")
    echo "  📍 Location: $geo"
    echo "  ℹ This server will be rate-limited to 5 connections/hour"
    echo "  💡 Consider adding this IP range to Irish allowlist if legitimate"
  fi
}

# Generate recommendations
generate_recommendations() {
  log_section "Security Recommendations"

  # Check if Irish IPs are being rate-limited (potential issue)
  local irish_limited=$(sudo journalctl --since="today" | grep "MC-RATE-LIMITED" | wc -l 2> /dev/null || echo "0")
  # Clean up any newlines or non-numeric characters
  irish_limited=${irish_limited//[^0-9]/}
  if [[ $irish_limited -gt 10 ]]; then
    log_warn "Irish IPs are being rate-limited ($irish_limited times today)"
    echo "  Consider increasing rate limits for Irish IPs"
  fi

  # Check for repeat offenders
  local repeat_patterns=$(sudo journalctl --since="today" | grep "MC-BLOCKED" \
    | grep -o 'SRC=[0-9.]*' | cut -d'=' -f2 | sort | uniq -c | sort -nr | head -5 || true)

  if [[ -n "$repeat_patterns" ]]; then
    echo ""
    echo "Consider permanent blocking for repeat offenders:"
    echo "$repeat_patterns" | while read -r count ip; do
      if [[ $count -gt 50 ]]; then
        local geo=$(get_geo_info "$ip")
        printf "  %-15s (%d attempts) - %s\n" "$ip" "$count" "$geo"
      fi
    done
  fi

  # Check fail2ban effectiveness
  local total_bans=0
  for jail in minecraft-scanner minecraft-flood minecraft-repeat-offender; do
    if sudo fail2ban-client status "$jail" > /dev/null 2>&1; then
      local banned=$(sudo fail2ban-client status "$jail" | grep "Currently banned:" | grep -o '[0-9]*' || echo "0")
      total_bans=$((total_bans + banned))
    fi
  done

  echo ""
  if [[ $total_bans -eq 0 ]]; then
    echo "No active fail2ban bans - system is working or no attacks detected"
  else
    echo "fail2ban has $total_bans active bans - system is actively protecting"
  fi
}

# Main analysis function
main() {
  echo ""
  log_info "Minecraft Server Security Analysis"
  echo "Generated: $(date)"
  echo "==================================================="

  analyze_fail2ban_status
  echo ""
  analyze_log_patterns
  echo ""
  analyze_effectiveness
  echo ""
  analyze_ipsets
  echo ""
  generate_recommendations

  echo ""
  log_info "Analysis complete. Monitor trends over time for better insights."
  echo ""
  echo "==============================================="
  echo "🔒 END OF SECURITY REPORT"
  echo "==============================================="
}

# Handle command line arguments
case "${1:-analyze}" in
  "analyze" | "")
    main
    ;;
  "status")
    analyze_fail2ban_status
    ;;
  "patterns")
    analyze_log_patterns
    ;;
  "effectiveness")
    analyze_effectiveness
    ;;
  *)
    echo "Usage: $0 {analyze|status|patterns|effectiveness}"
    echo ""
    echo "Commands:"
    echo "  analyze       - Full analysis (default)"
    echo "  status        - Show fail2ban status only"
    echo "  patterns      - Analyze attack patterns only"
    echo "  effectiveness - Show protection effectiveness only"
    exit 1
    ;;
esac
