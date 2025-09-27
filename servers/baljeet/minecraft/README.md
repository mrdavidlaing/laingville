# Minecraft Server Security System

Intelligent firewall and intrusion prevention system for Minecraft server protection.

## Overview

This security system provides multi-layered protection for your Minecraft server:

1. **Geographic Filtering** - Preferential treatment for Irish IPs
2. **Behavioral Analysis** - Detects scanning vs legitimate gameplay patterns  
3. **Automatic Banning** - fail2ban integration for persistent threats
4. **Rate Limiting** - Prevents flood attacks while allowing normal play
5. **Real-time Monitoring** - Comprehensive logging and analysis

## Features

### ✅ Smart Traffic Classification
- **Local Network**: Unlimited access (192.168.x.x, 10.x.x.x)
- **Irish IPs**: High rate limits (40 connections/hour)
- **Other IPs**: Conservative limits (5 connections/hour)
- **Scanners**: Automatic detection and blocking

### ✅ Behavioral Detection
- **SYN-only scanners**: Detect and block TCP port scanners
- **Connection floods**: Rate limiting and temporary bans
- **Repeat offenders**: Progressive ban times for persistent threats
- **Protocol validation**: Distinguish real Minecraft traffic from probes

### ✅ Automatic Response
- **Immediate**: Temporary blocks for obvious scanners (1 hour)
- **Short-term**: fail2ban bans for suspicious behavior (1-24 hours)
- **Long-term**: Extended bans for repeat offenders (24+ hours)

## Quick Start

### 1. Deploy the Security System
```bash
# Install packages and apply configurations
sudo ./bin/setup-server

# Or run manually
cd servers/baljeet/minecraft/scripts
sudo ./setup-minecraft-firewall.sh
```

### 2. Monitor Activity
```bash
# Real-time monitoring
sudo journalctl -f | grep 'MC-'

# Comprehensive analysis
./analyze-banned-ips.sh

# Check fail2ban status
sudo fail2ban-client status
```

### 3. Maintenance
```bash
# Update Irish IP ranges (run weekly)
sudo ./update-irish-ips.sh

# Check security status
sudo ./setup-minecraft-firewall.sh status
```

## File Structure

```
minecraft/
├── fail2ban/
│   ├── jail.d/
│   │   └── minecraft.conf         # fail2ban jail definitions
│   └── filter.d/
│       ├── minecraft-scanner.conf # Scanner detection patterns
│       └── minecraft-flood.conf   # Flood detection patterns
├── scripts/
│   ├── setup-minecraft-firewall.sh    # Main setup script
│   ├── update-irish-ips.sh           # IP range updates
│   └── analyze-banned-ips.sh         # Security analysis
├── ipsets/
│   └── README.md                      # IP set documentation
└── README.md                          # This file
```

## Configuration

### fail2ban Jails

#### minecraft-scanner
- **Purpose**: Detect port scanning and reconnaissance
- **Threshold**: 10 attempts in 10 minutes → 1 hour ban
- **Pattern**: SYN-only connections, rate-limited IPs

#### minecraft-flood  
- **Purpose**: Detect connection flooding attacks
- **Threshold**: 50 attempts in 1 minute → 30 minute ban
- **Pattern**: Rapid successive connections

#### minecraft-repeat-offender
- **Purpose**: Longer bans for persistent threats
- **Threshold**: 3 bans in 24 hours → 24 hour ban
- **Pattern**: IPs that keep getting banned

### iptables Rules

```bash
# Local network - unlimited access
ACCEPT: 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12

# Irish IPs - generous rate limiting  
ACCEPT: irish_ips (40/hour, burst 10)

# Temp scanner blocks
DROP: temp_scanners ipset

# SYN scanner detection
DETECT: SYN-only patterns → add to temp_scanners

# Non-Irish rate limiting
ACCEPT: other IPs (5/hour, burst 2)

# Default deny with logging
LOG + DROP: everything else
```

## Monitoring and Analysis

### Real-time Monitoring
```bash
# Watch all Minecraft security events
sudo journalctl -f | grep 'MC-'

# Watch fail2ban activity
sudo tail -f /var/log/fail2ban.log

# Watch iptables logs
sudo dmesg -w | grep MINECRAFT
```

### Daily Analysis
```bash
# Full security report
./analyze-banned-ips.sh

# Key metrics shown:
# - Currently banned IPs
# - Attack patterns and geography  
# - Protection effectiveness
# - Recommendations for tuning
```

### Log Patterns
- `MC-RATE-LIMITED`: Non-Irish IP hit rate limit
- `MC-TEMP-BLOCKED`: Scanner detected and blocked
- `MC-BLOCKED`: Default deny rule triggered
- `MINECRAFT-ATTEMPT`: All connection attempts (from existing logging)

## Expected Behavior

### Day 1: Learning Phase
- Initial setup with conservative thresholds
- German botnet IPs will likely get banned automatically
- Irish players should have seamless access
- Monitor for false positives

### Week 1: Pattern Recognition
- fail2ban learns common attack patterns
- Repeated offenders get longer bans
- Geographic patterns become clear
- Adjust thresholds based on real data

### Month 1: Steady State
- Most scanning attempts blocked automatically
- Low false positive rate
- Clear separation of legitimate vs malicious traffic
- Occasional tune-ups based on new attack patterns

## Troubleshooting

### Irish Player Can't Connect
```bash
# Check if Ireland IP ranges are current
./update-irish-ips.sh status

# Check if player IP is in rate limit
grep "PLAYER_IP" /var/log/kern.log | grep "MC-RATE-LIMITED"

# Manually add IP to Ireland set (temporary)
sudo ipset add ireland_ips PLAYER_IP/32
```

### Too Many False Positives
```bash
# Check current thresholds
sudo fail2ban-client get minecraft-scanner maxretry

# Increase thresholds (example)
sudo fail2ban-client set minecraft-scanner maxretry 20

# Whitelist specific IP
sudo fail2ban-client set minecraft-scanner addignoreip TRUSTED_IP
```

### System Not Blocking Obvious Attackers
```bash
# Check if rules are active
sudo iptables -L MINECRAFT_FILTER -n

# Check fail2ban status
sudo fail2ban-client status minecraft-scanner

# Manually ban IP
sudo fail2ban-client set minecraft-scanner banip ATTACKER_IP
```

## Security Considerations

### What This Protects Against
- ✅ Port scanning and reconnaissance
- ✅ Connection flooding (DDoS attempts)
- ✅ Brute force connection attempts  
- ✅ Automated bot networks
- ✅ Random internet scanning

### What This Doesn't Protect Against
- ❌ Minecraft protocol exploits (needs server-side protection)
- ❌ DDoS attacks exceeding server capacity
- ❌ Social engineering of legitimate players
- ❌ Compromised legitimate player accounts

### Best Practices
1. **Monitor regularly** - Check analysis reports weekly
2. **Update IP ranges** - Run update script monthly
3. **Backup configurations** - Keep fail2ban and iptables configs versioned
4. **Test with friends** - Verify Irish players can connect normally
5. **Document changes** - Note any manual IP additions or rule changes

## Performance Impact

- **CPU**: Minimal - iptables rules are efficient
- **Memory**: Low - ipsets store IPs efficiently
- **Latency**: None for accepted connections
- **Logs**: Moderate increase due to security logging

## Integration with Laingville

The security system integrates seamlessly with the Laingville server management:

1. **Packages**: Automatically installed via `packages.yaml`
2. **Configuration**: Version controlled with server configs
3. **Deployment**: Applied via `setup-server` script
4. **Monitoring**: Uses existing logging infrastructure

## Future Enhancements

Potential improvements based on observed attack patterns:

1. **Subnet blocking** for coordinated attacks
2. **Time-based rules** for known attack periods
3. **Integration with threat intelligence** feeds
4. **Automated reporting** for security incidents
5. **Machine learning** for pattern detection

---

**Questions or Issues?**
- Check logs: `sudo journalctl -f | grep 'MC-'`
- Run analysis: `./analyze-banned-ips.sh`
- Review fail2ban: `sudo fail2ban-client status`