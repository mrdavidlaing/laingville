#!/bin/sh
# Simple Entware installation script for FreshTomato on dwaca
# Assumes USB drive mounted at /tmp/mnt/dwaca-usb with ext4 filesystem

set -e

echo "Installing Entware on dwaca..."

# Configure network and DNS for internet access
echo "Setting up network gateway..."
route add default gw 192.168.1.1 2> /dev/null || echo "Gateway already configured"

echo "Setting up DNS servers..."
echo "nameserver 1.1.1.1" > /etc/resolv.dnsmasq
echo "nameserver 8.8.8.8" >> /etc/resolv.dnsmasq
echo "Restarting dnsmasq service..."
service dnsmasq restart
sleep 2
echo "Testing DNS..."
nslookup google.com || echo "DNS still not working, continuing anyway..."

# Set router hostname and domain persistently via NVRAM
echo "Setting router hostname and domain in NVRAM..."
nvram set router_name=dwaca
nvram set lan_hostname=dwaca
nvram set wan_hostname=dwaca
nvram set lan_domain=laingville.internal
nvram set domain=laingville.internal
# Note: wan_domain is auto-constructed by FreshTomato as hostname.domain
nvram commit

# Apply hostname immediately for current session
echo "Setting system hostname to dwaca..."
hostname dwaca
echo "dwaca" > /proc/sys/kernel/hostname
echo "127.0.0.1 localhost dwaca" > /etc/hosts
echo "192.168.1.2 dwaca.laingville.internal dwaca" >> /etc/hosts

# Clean up any existing mounts and directories
echo "Cleaning up existing Entware installation..."
umount /opt 2> /dev/null || true
rm -rf /tmp/mnt/dwaca-usb/entware

# Create fresh entware directory
mkdir -p "/tmp/mnt/dwaca-usb/entware"

# Bind mount entware directory to /opt
echo "Mounting entware directory to /opt..."
if mount --bind "/tmp/mnt/dwaca-usb/entware" /opt; then
  echo "Successfully mounted /tmp/mnt/dwaca-usb/entware to /opt"
else
  echo "Failed to mount entware directory"
  exit 1
fi

# Download and install Entware for ARM
echo "Downloading Entware installer..."
cd /tmp
if wget -O entware_install.sh "http://pkg.entware.net/binaries/armv7/installer/entware_install.sh"; then
  echo "Running Entware installer..."
  sh entware_install.sh
else
  echo "Failed to download Entware installer"
  exit 1
fi

# Update packages and install essentials
echo "Installing bash and rsync..."
if /opt/bin/opkg update; then
  /opt/bin/opkg install bash rsync
else
  echo "Failed to update package list"
  exit 1
fi

# Create auto-start script
cat > "/tmp/mnt/dwaca-usb/.autorun" << 'EOF'
#!/bin/sh
mount --bind /tmp/mnt/dwaca-usb/entware /opt
/opt/etc/init.d/rc.unslung start
EOF
chmod +x "/tmp/mnt/dwaca-usb/.autorun"

# Create auto-stop script
cat > "/tmp/mnt/dwaca-usb/.autostop" << 'EOF'
#!/bin/sh
/opt/etc/init.d/rc.unslung stop
umount /opt
EOF
chmod +x "/tmp/mnt/dwaca-usb/.autostop"

echo "Entware installation complete!"
echo "Installed: bash, rsync"
echo "Reboot router to activate auto-start scripts"
