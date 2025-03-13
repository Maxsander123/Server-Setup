#!/bin/bash

# This script configures a static IP using Netplan
# and uses dialog for a text-based GUI interface.

# Prompt for network interface name with default "ens3"
interface=$(dialog --inputbox "Enter the network interface name (e.g. ens3)" 8 40 "ens3" 3>&1 1>&2 2>&3 3>&-)

# Prompt for static IPv4 configuration.
ip_addr=$(dialog --inputbox "Enter static IPv4 address (CIDR notation, e.g. 192.168.1.100/24)" 8 60 3>&1 1>&2 2>&3 3>&-)
gateway=$(dialog --inputbox "Enter Gateway (e.g. 192.168.1.1)" 8 40 3>&1 1>&2 2>&3 3>&-)
dns=$(dialog --inputbox "Enter DNS server (e.g. 8.8.8.8)" 8 40 3>&1 1>&2 2>&3 3>&-)

# Prompt for IPv6 activation.
dialog --yesno "Enable IPv6?" 8 40
if [ $? -eq 0 ]; then
    dhcp6_value="true"
else
    dhcp6_value="false"
fi

# Backup any existing Netplan configuration (if present).
if [ -f /etc/netplan/50-netcfg.yaml ]; then
    sudo cp /etc/netplan/50-netcfg.yaml /etc/netplan/50-netcfg.yaml.bak
    dialog --msgbox "Existing configuration backed up to /etc/netplan/50-netcfg.yaml.bak" 8 60
fi

# Create new Netplan configuration.
sudo bash -c "cat > /etc/netplan/50-netcfg.yaml" <<EOF
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

dialog --msgbox "Static IP configuration applied. Testing connectivity..." 8 60

# Ping 8.8.8.8 for 4 seconds.
ping -w 4 8.8.8.8 > /dev/null 2>&1
ipv4_result=$?

# Ping google.com for 4 seconds.
ping -w 4 google.com > /dev/null 2>&1
google_result=$?

if [ $ipv4_result -eq 0 ] && [ $google_result -eq 0 ]; then
    dialog --msgbox "Everything works" 8 40
else
    dialog --msgbox "Connectivity test failed." 8 40
fi

clear
