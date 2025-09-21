#!/opt/bin/bash
# Apply time synchronization for FreshTomato router

set -euo pipefail

echo "Applying time synchronization..."

# Sync time immediately using ntpdate (from Entware package)
if command -v /opt/bin/ntpdate > /dev/null 2>&1; then
  /opt/bin/ntpdate -s time.google.com 2> /dev/null || echo "Entware ntpdate failed, but continuing..."
else
  echo "ntpdate not available, relying on FreshTomato NTP client..."
fi

# Configure NTP settings in NVRAM
nvram set ntp_enable=1
nvram set ntp_server="time.google.com pool.ntp.org"
nvram set ntp_timezone="IST-1IDT,M3.5.0,M10.5.0/1"

# Set timezone immediately in /etc/TZ for current session
echo "IST-1IDT,M3.5.0,M10.5.0/1" > /etc/TZ

# Disable ntpd daemon to prevent conflicts with FreshTomato's NTP client
nvram set ntpd_enable=0

nvram commit

echo "Time synchronization configured successfully"
