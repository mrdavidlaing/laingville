# IP Sets for Minecraft Server Security

This directory is used by the Minecraft security system to store IP set data.

## IP Sets Used

### `ireland_ips`
- **Type**: hash:net
- **Purpose**: Contains Irish IP ranges for preferential treatment
- **Updated**: Weekly via `update-irish-ips.sh`
- **Source**: RIPE database via ipdeny.com

### `temp_scanners`
- **Type**: hash:ip with timeout
- **Purpose**: Temporarily blocks IPs detected as scanners
- **Timeout**: 1 hour
- **Detection**: SYN-only connections pattern

### fail2ban IP sets
Created automatically by fail2ban:
- `minecraft-scanners`: IPs banned for scanning behavior
- `minecraft-floods`: IPs banned for connection flooding
- `minecraft-repeat`: IPs banned as repeat offenders

## Management Commands

```bash
# List all IP sets
sudo ipset list

# Show specific set
sudo ipset list ireland_ips

# Add IP to temporary scanner block
sudo ipset add temp_scanners 1.2.3.4

# Remove IP from set
sudo ipset del temp_scanners 1.2.3.4

# Save current sets
sudo ipset save > /tmp/ipsets_backup.txt

# Restore sets
sudo ipset restore < /tmp/ipsets_backup.txt
```

## Monitoring

The IP sets are automatically monitored by the analysis scripts:
- Current counts shown in `analyze-banned-ips.sh`
- Updates logged via system logs
- fail2ban manages its own sets automatically

## Backup and Recovery

IP sets are not persistent by default. The setup script recreates them on boot.
For persistent storage across reboots, consider installing `ipset-persistent` package.