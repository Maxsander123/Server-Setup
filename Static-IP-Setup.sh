#!/bin/bash

# Prompt for network interface name; default to "ens3" if left empty.
read -p "Enter the network interface name (e.g. ens3) [Default: ens3]: " interface
interface=${interface:-ens3}

# Prompt for static IPv4 configuration.
read -p "Enter static IPv4 address (CIDR notation, e.g. 192.168.1.100/24): " ip_addr
read -p "Enter Gateway (e.g. 192.168.1.1): " gateway
read -p "Enter DNS server (e.g. 8.8.8.8): " dns

# Prompt for IPv6 activation.
read -p "Enable IPv6? (y/n): " ipv6_choice
if [[ "$ipv6_choice" =~ ^[Yy]$ ]]; then
    dhcp6_value="true"
else
    dhcp6_value="false"
fi

# Backup any existing Netplan configuration (if present).
if [ -f /etc/netplan/01-netcfg.yaml ]; then
    sudo cp /etc/netplan/01-netcfg.yaml /etc/netplan/01-netcfg.yaml.bak
    echo "Existing configuration backed up to /etc/netplan/01-netcfg.yaml.bak"
fi

# Create new Netplan configuration.
sudo bash -c "cat > /etc/netplan/01-netcfg.yaml" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      addresses: [$ip_addr]
      gateway4: $gateway
      nameservers:
        addresses: [$dns]
      dhcp4: false
      dhcp6: $dhcp6_value
EOF

# Apply the new Netplan configuration.
sudo netplan apply

echo "Static IP configuration applied. Testing connectivity..."

# Ping 8.8.8.8 for 4 seconds.
ping -w 4 8.8.8.8 > /dev/null 2>&1
ipv4_result=$?

# Ping google.com for 4 seconds.
ping -w 4 google.com > /dev/null 2>&1
google_result=$?

if [ $ipv4_result -eq 0 ] && [ $google_result -eq 0 ]; then
    echo "everything works"
else
    echo "Connectivity test failed."
fi
