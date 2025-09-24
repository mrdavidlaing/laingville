#!/bin/bash
# Iptables Log Analyzer for Minecraft Server Traffic
# Analyzes kernel logs for Minecraft connection attempts logged by iptables

set -euo pipefail

LOG_PREFIX="MINECRAFT"
TEMP_DIR="/tmp/iptables-minecraft-analysis"
KERN_LOG="/var/log/kern.log"
JOURNAL_LOGS="journal"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create temp directory
mkdir -p "$TEMP_DIR"

# Function to extract iptables logs
extract_iptables_logs() {
  local output_file="$1"
  local days="${2:-1}" # Default to last 1 day

  # Try kern.log first
  if [[ -r "$KERN_LOG" ]]; then
    log_info "Extracting from $KERN_LOG (last $days days)"
    # Get logs from last N days
    since_date=$(date -d "$days days ago" '+%b %d')
    grep "$LOG_PREFIX" "$KERN_LOG" | grep "$since_date" > "$output_file" 2> /dev/null || true

    # Also get today's logs if different date format
    today_date=$(date '+%b %d')
    if [[ "$since_date" != "$today_date" ]]; then
      grep "$LOG_PREFIX" "$KERN_LOG" | grep "$today_date" >> "$output_file" 2> /dev/null || true
    fi
  fi

  # Also try journalctl for recent logs
  if command -v journalctl > /dev/null 2>&1; then
    log_info "Extracting from journalctl (last $days days)"
    journalctl --since="$days days ago" | grep "$LOG_PREFIX" >> "$output_file" 2> /dev/null || true
  fi

  # Remove duplicates and sort by time
  if [[ -f "$output_file" ]]; then
    sort -u "$output_file" -o "$output_file"
  fi
}

# Function to parse connection attempts
parse_connections() {
  local log_file="$1"
  local parsed_file="$TEMP_DIR/parsed_connections.txt"

  if [[ ! -s "$log_file" ]]; then
    touch "$parsed_file"
    echo "$parsed_file"
    return
  fi

  # Extract timestamp, source IP, source port, destination port
  while IFS= read -r line; do
    # Parse iptables log format: timestamp SRC=x.x.x.x DST=x.x.x.x SPT=xxxx DPT=25565
    timestamp=$(echo "$line" | grep -o '^[A-Z][a-z][a-z] [0-9 :]*' || true)
    src_ip=$(echo "$line" | grep -o 'SRC=[0-9.]*' | cut -d'=' -f2 || true)
    src_port=$(echo "$line" | grep -o 'SPT=[0-9]*' | cut -d'=' -f2 || true)
    dst_port=$(echo "$line" | grep -o 'DPT=[0-9]*' | cut -d'=' -f2 || true)

    if [[ -n "$timestamp" && -n "$src_ip" && -n "$dst_port" ]]; then
      echo "$timestamp|$src_ip|$src_port|$dst_port"
    fi
  done < "$log_file" > "$parsed_file"

  echo "$parsed_file"
}

# Function to analyze IP patterns
analyze_ips() {
  local parsed_file="$1"
  local ip_stats="$TEMP_DIR/ip_stats.txt"

  if [[ ! -s "$parsed_file" ]]; then
    touch "$ip_stats"
    echo "$ip_stats"
    return
  fi

  # Count connections per IP
  cut -d'|' -f2 "$parsed_file" | sort | uniq -c | sort -nr > "$ip_stats"
  echo "$ip_stats"
}

# Function to classify IPs
classify_ips() {
  local ip_stats="$1"
  local local_ips="$TEMP_DIR/local_ips.txt"
  local external_ips="$TEMP_DIR/external_ips.txt"

  # Split into local and external
  grep -E "(192\.168\.|10\.|127\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)" "$ip_stats" > "$local_ips" 2> /dev/null || touch "$local_ips"
  grep -vE "(192\.168\.|10\.|127\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)" "$ip_stats" > "$external_ips" 2> /dev/null || touch "$external_ips"

  echo "$local_ips $external_ips"
}

# Function to detect scanning patterns
detect_scanning() {
  local parsed_file="$1"
  local scan_report="$TEMP_DIR/scan_analysis.txt"

  if [[ ! -s "$parsed_file" ]]; then
    touch "$scan_report"
    echo "$scan_report"
    return
  fi

  echo "=== SCANNING PATTERN ANALYSIS ===" > "$scan_report"

  # Look for rapid connections from same IP (potential port scan)
  {
    echo "IPs with >5 attempts in dataset:"
    cut -d'|' -f2 "$parsed_file" | sort | uniq -c | sort -nr | awk '$1 > 5 { print "  " $2 ": " $1 " attempts" }'
    echo ""
    echo "Port diversity per IP (potential port scan indicators):"
    awk -F'|' '{ip_ports[$2][$4]++} END {
        for (ip in ip_ports) {
            port_count = 0
            for (port in ip_ports[ip]) port_count++
            if (port_count > 1) {
                printf "  %s: tried %d different ports\n", ip, port_count
            }
        }
    }' "$parsed_file"
    echo ""
    echo "Rapid succession attempts (potential automated scanning):"
    awk -F'|' '{
        gsub(/[^0-9:]/, "", $1)  # Clean timestamp
        attempts[$2] = attempts[$2] " " $1
    } END {
        for (ip in attempts) {
            count = split(attempts[ip], times, " ")
            if (count > 3) {
                printf "  %s: %d attempts\n", ip, count-1
            }
        }
    }' "$parsed_file"
  } >> "$scan_report"

  echo "$scan_report"
}

# Function to get geographic info
get_geo_info() {
  local ip="$1"
  if command -v geoiplookup > /dev/null 2>&1; then
    geoiplookup "$ip" | head -1 | cut -d' ' -f4- | sed 's/^, //' || echo "Unknown"
  else
    echo "GeoIP not available"
  fi
}

# Function to generate timeline
generate_timeline() {
  local parsed_file="$1"
  local timeline="$TEMP_DIR/timeline.txt"

  if [[ ! -s "$parsed_file" ]]; then
    touch "$timeline"
    echo "$timeline"
    return
  fi

  # Count attempts per hour
  echo "=== HOURLY TIMELINE ===" > "$timeline"
  awk -F'|' '{
        # Extract hour from timestamp
        if (match($1, /[0-9]{2}:[0-9]{2}/)) {
            hour = substr($1, RSTART, 2)
            hours[hour]++
        }
    } END {
        for (h = 0; h < 24; h++) {
            printf "%02d:00 - %02d:59: %d attempts\n", h, h, (hours[sprintf("%02d", h)] ? hours[sprintf("%02d", h)] : 0)
        }
    }' "$parsed_file" >> "$timeline"

  echo "$timeline"
}

# Main analysis function
main() {
  local days="${1:-1}"

  log_info "Starting iptables log analysis for Minecraft traffic"
  echo "Analysis period: Last $days day(s)"
  echo "=============================================="

  # Extract logs
  log_file="$TEMP_DIR/minecraft_iptables.log"
  extract_iptables_logs "$log_file" "$days"

  if [[ ! -s "$log_file" ]]; then
    log_warn "No iptables logs found for Minecraft traffic"
    echo "This could mean:"
    echo "  1. iptables logging is not enabled yet"
    echo "  2. No connection attempts have been made"
    echo "  3. Logs have been rotated"
    echo ""
    echo "To enable logging, run:"
    echo "  sudo $(dirname "$0")/setup-iptables-logging.sh setup"
    exit 0
  fi

  total_entries=$(wc -l < "$log_file")
  log_info "Found $total_entries iptables log entries"

  # Parse connections
  parsed_file=$(parse_connections "$log_file")
  connection_count=$(wc -l < "$parsed_file" 2> /dev/null || echo 0)

  if [[ $connection_count -eq 0 ]]; then
    log_warn "No valid connection attempts parsed from logs"
    exit 0
  fi

  echo ""
  echo -e "${BLUE}=== IPTABLES CONNECTION SUMMARY ===${NC}"
  echo "Total log entries: $total_entries"
  echo "Parsed connections: $connection_count"

  # Analyze IPs
  ip_stats=$(analyze_ips "$parsed_file")
  unique_ips=$(wc -l < "$ip_stats" 2> /dev/null || echo 0)

  read -r local_ips external_ips <<< "$(classify_ips "$ip_stats")"
  local_count=$(wc -l < "$local_ips" 2> /dev/null || echo 0)
  external_count=$(wc -l < "$external_ips" 2> /dev/null || echo 0)

  echo "Unique source IPs: $unique_ips"
  echo "Local network IPs: $local_count"
  echo "External IPs: $external_count"

  # Show top IPs
  echo ""
  echo -e "${BLUE}=== TOP CONNECTION SOURCES ===${NC}"
  head -10 "$ip_stats" | while read -r count ip; do
    if [[ -n "$ip" ]]; then
      if echo "$ip" | grep -qE "(192\.168\.|10\.|127\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)"; then
        type="[LOCAL]"
        geo_info=""
      else
        type="[EXTERNAL]"
        geo_info=" - $(get_geo_info "$ip")"
      fi
      printf "%-15s %4d attempts %s%s\n" "$ip" "$count" "$type" "$geo_info"
    fi
  done

  # External IP details
  if [[ $external_count -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}=== EXTERNAL IP ANALYSIS ===${NC}"
    while read -r count ip; do
      if [[ -n "$ip" ]]; then
        geo_info=$(get_geo_info "$ip")
        printf "%-15s %4d attempts - %s\n" "$ip" "$count" "$geo_info"
      fi
    done < "$external_ips"
  fi

  # Scanning analysis
  scan_report=$(detect_scanning "$parsed_file")
  if [[ -s "$scan_report" ]]; then
    echo ""
    echo -e "${PURPLE}=== SECURITY ANALYSIS ===${NC}"
    cat "$scan_report"
  fi

  # Timeline
  timeline=$(generate_timeline "$parsed_file")
  if [[ -s "$timeline" ]]; then
    echo ""
    echo -e "${BLUE}=== ACTIVITY TIMELINE ===${NC}"
    cat "$timeline"
  fi

  # Show sample log entries
  echo ""
  echo -e "${BLUE}=== SAMPLE LOG ENTRIES ===${NC}"
  head -3 "$log_file" | while IFS= read -r line; do
    echo "  $line"
  done

  log_info "Analysis complete. Temp files in: $TEMP_DIR"
  log_info "To monitor real-time: sudo journalctl -f | grep $LOG_PREFIX"
}

# Cleanup function
cleanup() {
  if [[ "${1:-}" != "--keep-temp" ]]; then
    rm -rf "$TEMP_DIR" 2> /dev/null || true
  fi
}

# Show help
show_help() {
  echo "Usage: $0 [days] [--keep-temp]"
  echo ""
  echo "Options:"
  echo "  days        Number of days to analyze (default: 1)"
  echo "  --keep-temp Keep temporary files for debugging"
  echo ""
  echo "Examples:"
  echo "  $0          # Analyze last 24 hours"
  echo "  $0 7        # Analyze last 7 days"
  echo "  $0 1 --keep-temp  # Keep temp files"
}

# Parse arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  show_help
  exit 0
fi

# Set up trap for cleanup
trap cleanup EXIT

# Run analysis
main "$@"
