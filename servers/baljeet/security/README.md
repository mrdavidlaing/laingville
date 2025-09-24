# Minecraft Server Security Monitoring

This directory contains tools for monitoring and analyzing connection attempts to the Minecraft server on port 25565.

## Current Status

**✅ Baseline Analysis Complete**: Your Minecraft server is already receiving external connections:
- 19 total connections found in logs
- 2 external IP addresses have connected: `51.37.157.161` and `109.76.241.109`
- No suspicious patterns detected in current data
- Most traffic is from local network (192.168.1.x)

## Tools Available

### 1. Minecraft Server Log Analysis
**File**: `minecraft-log-analyzer.sh`

Analyzes existing Minecraft server logs from `/var/log/minecraft/` to understand connection patterns.

```bash
# Run analysis on recent connections
./minecraft-log-analyzer.sh

# Shows:
# - Total connections and unique IPs
# - Local vs external IP classification
# - Top connecting IPs with geographic info (if geoip installed)
# - Security assessment for suspicious patterns
# - Time range of data analyzed
```

**Features**:
- Parses both compressed logs (`*.log.gz`) and current log (`latest.log`)
- Detects external vs local network connections
- Geographic IP lookup (requires `geoip` package)
- Suspicious activity detection (>10 connections from same IP)
- Clean, colored output with security warnings

### 2. iptables Traffic Logging Setup
**File**: `setup-iptables-logging.sh`

Sets up kernel-level logging of all connection attempts to port 25565, including failed/rejected connections that don't appear in Minecraft logs.

```bash
# Enable iptables logging (requires sudo)
sudo ./setup-iptables-logging.sh setup

# Show current iptables rules
sudo ./setup-iptables-logging.sh show

# Remove logging rules
sudo ./setup-iptables-logging.sh remove

# Test logging setup
sudo ./setup-iptables-logging.sh test
```

**Features**:
- Logs ALL connection attempts (successful and failed)
- Rate limiting to prevent log spam (10/min with 20 burst)
- Custom `MINECRAFT_LOG` iptables chain for clean management
- Logs to `/var/log/kern.log` and journalctl
- Easy setup/removal without breaking existing rules

### 3. iptables Log Analysis
**File**: `iptables-log-analyzer.sh`

Analyzes kernel logs for iptables-logged connection attempts, providing detailed security analysis.

```bash
# Analyze last 24 hours of iptables logs
./iptables-log-analyzer.sh

# Analyze last 7 days
./iptables-log-analyzer.sh 7

# Keep temp files for debugging
./iptables-log-analyzer.sh 1 --keep-temp
```

**Features**:
- Parses iptables log format from kernel logs and journalctl
- Detects port scanning patterns (rapid connections, multiple ports)
- Geographic IP analysis for external connections
- Hourly timeline of connection attempts
- Security analysis highlighting suspicious behavior
- Works with both syslog and systemd journal

## Recommended Workflow

### 1. Initial Setup
```bash
# Install GeoIP for location data
sudo pacman -S geoip  # Already added to packages.yaml

# Enable iptables logging
sudo ./setup-iptables-logging.sh setup

# Run initial analysis
./minecraft-log-analyzer.sh
```

### 2. Daily Monitoring
```bash
# Check Minecraft server logs for successful connections
./minecraft-log-analyzer.sh

# Check iptables logs for all connection attempts (including failed ones)
./iptables-log-analyzer.sh

# Compare the two to understand:
# - How many attempts succeed vs fail
# - If there are connection attempts not reaching Minecraft
# - Port scanning or brute force attempts
```

### 3. After Port Forward Goes Live
```bash
# Run both analyzers to see the change in traffic patterns
./minecraft-log-analyzer.sh
./iptables-log-analyzer.sh 7  # Check weekly trends

# Look for:
# - Sudden increase in external IPs
# - Port scanning attempts
# - Geographic distribution of connections
# - Failed vs successful connection ratios
```

## Log Locations

- **Minecraft Server Logs**: `/var/log/minecraft/`
  - `latest.log` - Current session
  - `YYYY-MM-DD-*.log.gz` - Compressed historical logs

- **iptables Logs**: `journalctl` (systemd journal)
  - Look for entries with prefix `MINECRAFT:`
  - Real-time monitoring: `sudo journalctl -f | grep MINECRAFT`

## Security Insights

The analysis tools help identify:

1. **Legitimate Traffic**:
   - Known player IP ranges
   - Normal connection patterns
   - Successful Minecraft protocol handshakes

2. **Suspicious Activity**:
   - Multiple rapid connections from single IP
   - Port scanning (connections to multiple ports)
   - Connections from high-risk geographic regions
   - Failed authentication attempts

3. **Baseline vs Attack Traffic**:
   - Current: ~2 external IPs connecting
   - Future: Compare against this baseline to detect attacks
   - Threshold recommendations based on normal usage patterns

## Integration with fail2ban (Future)

The logging infrastructure is designed to support fail2ban integration:

- iptables logs provide fail2ban with connection attempt data
- Custom log prefixes make pattern matching easy
- Rate limiting prevents log flooding
- Clean rule management allows adding/removing fail2ban rules

## Troubleshooting

### No iptables logs found
1. Ensure logging is enabled: `sudo ./setup-iptables-logging.sh show`
2. Check if logs are being written: `sudo journalctl | grep MINECRAFT | tail`
3. Test with a connection attempt and check real-time logs

### GeoIP not working
1. Install package: `sudo pacman -S geoip`
2. Update GeoIP database if needed
3. Test with: `geoiplookup 8.8.8.8`

### Permission errors
- iptables setup requires sudo
- Log analysis scripts can run as regular user
- Minecraft logs in `/var/log/minecraft/` should be readable by all users