#!/bin/bash
# Minecraft Server Log Analyzer
# Analyzes connection patterns from Minecraft server logs

set -euo pipefail

MINECRAFT_LOG_DIR="/var/log/minecraft"
TEMP_DIR="/tmp/minecraft-analysis"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if we have access to logs
if [[ ! -r "$MINECRAFT_LOG_DIR" ]]; then
  log_error "Cannot read Minecraft logs at $MINECRAFT_LOG_DIR"
  exit 1
fi

# Create temp directory
mkdir -p "$TEMP_DIR"

# Extract all connection data
extract_connections() {
  local all_logs="$TEMP_DIR/all_connections.txt"

  # Process compressed logs
  if ls "$MINECRAFT_LOG_DIR"/*.log.gz > /dev/null 2>&1; then
    zcat "$MINECRAFT_LOG_DIR"/*.log.gz | grep -E "logged in with entity id" > "$all_logs" || true
  else
    touch "$all_logs"
  fi

  # Process current log
  if [[ -f "$MINECRAFT_LOG_DIR/latest.log" ]]; then
    grep -E "logged in with entity id" "$MINECRAFT_LOG_DIR/latest.log" >> "$all_logs" 2> /dev/null || true
  fi

  echo "$all_logs"
}

# Analyze IP patterns
analyze_ips() {
  local connections_file="$1"
  local ip_analysis="$TEMP_DIR/ip_analysis.txt"

  # Extract IPs with connection counts
  grep -o '\[/[^]]*\]' "$connections_file" \
    | sed 's/\[\/\([^:]*\):.*/\1/' \
    | sort | uniq -c | sort -nr > "$ip_analysis"

  echo "$ip_analysis"
}

# Classify IPs as local vs external
classify_ips() {
  local ip_file="$1"
  local local_ips="$TEMP_DIR/local_ips.txt"
  local external_ips="$TEMP_DIR/external_ips.txt"

  # Local IP patterns: 192.168.x.x, 10.x.x.x, 172.16-31.x.x, 127.x.x.x
  grep -E "(192\.168\.|10\.|127\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)" "$ip_file" > "$local_ips" || true
  grep -vE "(192\.168\.|10\.|127\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)" "$ip_file" > "$external_ips" || true

  echo "$local_ips $external_ips"
}

# Get geographic info for external IPs (if geoiplookup is available)
get_geo_info() {
  local ip="$1"
  if command -v geoiplookup > /dev/null 2>&1; then
    geoiplookup "$ip" | head -1 | cut -d' ' -f4- || echo "Unknown"
  else
    echo "GeoIP not available"
  fi
}

# Generate daily stats
daily_stats() {
  local connections_file="$1"
  local daily_stats="$TEMP_DIR/daily_stats.txt"

  # Extract dates and count connections per day
  grep -o '^\[[0-9]*:[0-9]*:[0-9]*\]' "$connections_file" \
    | cut -d: -f1-2 | sort | uniq -c > "$daily_stats" || true

  echo "$daily_stats"
}

# Main analysis function
main() {
  log_info "Starting Minecraft Server Log Analysis"
  echo "========================================"

  # Extract connection data
  log_info "Extracting connection data..."
  connections_file=$(extract_connections)

  if [[ ! -s "$connections_file" ]]; then
    log_warn "No connection data found in logs"
    exit 0
  fi

  total_connections=$(wc -l < "$connections_file")
  log_info "Found $total_connections total connection attempts"

  # Analyze IPs
  log_info "Analyzing IP patterns..."
  ip_analysis=$(analyze_ips "$connections_file")
  unique_ips=$(wc -l < "$ip_analysis")

  echo ""
  echo -e "${BLUE}=== CONNECTION SUMMARY ===${NC}"
  echo "Total Connections: $total_connections"
  echo "Unique IP Addresses: $unique_ips"

  # Classify local vs external
  read -r local_ips external_ips <<< "$(classify_ips "$ip_analysis")"
  local_count=$(wc -l < "$local_ips" 2> /dev/null || echo 0)
  external_count=$(wc -l < "$external_ips" 2> /dev/null || echo 0)

  echo ""
  echo -e "${BLUE}=== IP CLASSIFICATION ===${NC}"
  echo "Local Network IPs: $local_count"
  echo "External IPs: $external_count"

  if [[ $external_count -gt 0 ]]; then
    log_warn "Found external connections! This indicates the server is already accessible from outside"
    echo ""
    echo -e "${YELLOW}=== EXTERNAL IP DETAILS ===${NC}"
    while read -r count ip; do
      if [[ -n "$ip" ]]; then
        geo_info=$(get_geo_info "$ip")
        printf "%-15s %3s connections - %s\n" "$ip" "$count" "$geo_info"
      fi
    done < "$external_ips"
  fi

  echo ""
  echo -e "${BLUE}=== TOP CONNECTING IPs ===${NC}"
  head -10 "$ip_analysis" | while read -r count ip; do
    if [[ -n "$ip" ]]; then
      # Check if it's local or external
      if echo "$ip" | grep -qE "(192\.168\.|10\.|127\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)"; then
        type="[LOCAL]"
      else
        type="[EXTERNAL]"
        geo_info=" - $(get_geo_info "$ip")"
      fi
      printf "%-15s %3s connections %s%s\n" "$ip" "$count" "$type" "${geo_info:-}"
    fi
  done

  # Check for suspicious patterns
  echo ""
  echo -e "${BLUE}=== SECURITY ASSESSMENT ===${NC}"

  # Look for rapid connections from same IP
  suspicious_ips=$(awk '$1 > 10' "$ip_analysis" | wc -l)
  if [[ $suspicious_ips -gt 0 ]]; then
    log_warn "Found $suspicious_ips IP(s) with >10 connections - may indicate automated activity"
    awk '$1 > 10' "$ip_analysis" | while read -r count ip; do
      echo "  - $ip: $count connections"
    done
  else
    log_info "No suspicious connection patterns detected"
  fi

  # Show time range of data
  if [[ -s "$connections_file" ]]; then
    first_connection=$(head -1 "$connections_file" | grep -o '^\[[^]]*\]' | tr -d '[]')
    last_connection=$(tail -1 "$connections_file" | grep -o '^\[[^]]*\]' | tr -d '[]')
    echo ""
    echo -e "${BLUE}=== DATA RANGE ===${NC}"
    echo "First connection: $first_connection"
    echo "Last connection: $last_connection"
  fi

  log_info "Analysis complete. Temp files in: $TEMP_DIR"
}

# Cleanup function
cleanup() {
  if [[ "${1:-}" != "--keep-temp" ]]; then
    rm -rf "$TEMP_DIR" 2> /dev/null || true
  fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Run main analysis
main "$@"
