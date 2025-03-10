#!/bin/bash
# Ubuntu Server Functionality and Stress Test Script with Summary
# This script performs a series of basic checks on an Ubuntu server,
# runs a stress test, and prints a summary of the results.
# Run this script with sufficient privileges (some commands require sudo).

# Function to print a separator
print_separator() {
  echo "------------------------------------------------------------"
}

# Collect OS Information
print_separator
echo "OS Information:"
if command -v lsb_release &> /dev/null; then
  os_info=$(lsb_release -a 2>/dev/null)
  echo "$os_info"
else
  os_info=$(cat /etc/os-release)
  echo "$os_info"
fi

# Collect Uptime
print_separator
echo "System Uptime:"
uptime_info=$(uptime)
echo "$uptime_info"

# Collect Disk Usage
print_separator
echo "Disk Usage:"
disk_usage=$(df -h)
echo "$disk_usage"

# Collect Memory Usage
print_separator
echo "Memory Usage:"
mem_usage=$(free -h)
echo "$mem_usage"

# Collect CPU Load
print_separator
echo "CPU Load:"
cpu_load=$(top -bn1 | grep "load average:")
echo "$cpu_load"

# Test Network Connectivity
print_separator
echo "Network Connectivity Test (ping google.com):"
if ping -c 4 google.com &> /dev/null; then
  net_status="Network is up."
  echo "$net_status"
else
  net_status="Network seems down or google.com is unreachable."
  echo "$net_status"
fi

# Check Firewall Status (UFW)
print_separator
echo "Firewall Status (UFW):"
if command -v ufw &> /dev/null; then
  fw_status=$(sudo ufw status verbose)
  echo "$fw_status"
else
  fw_status="ufw is not installed."
  echo "$fw_status"
fi

# Check for Open Ports
print_separator
echo "Open Ports:"
open_ports=$(sudo ss -tuln)
echo "$open_ports"

# Check Critical Services (SSH, Apache2, Nginx)
print_separator
services_status=""
for service in ssh apache2 nginx; do
  services_status+="Service: $service\n"
  if systemctl list-units --type=service | grep -q "$service"; then
    status=$(systemctl status "$service" --no-pager | head -n 5)
    services_status+="$status\n"
  else
    services_status+="Service '$service' is not installed.\n"
  fi
  services_status+="\n"
done
echo -e "$services_status"

# Run a Stress Test
print_separator
echo "Running Stress Test for 60 seconds..."
if ! command -v stress &> /dev/null; then
  echo "'stress' tool is not installed. Installing..."
  sudo apt-get update && sudo apt-get install -y stress
fi
stress --cpu 4 --io 2 --vm 2 --vm-bytes 128M --timeout 60s
stress_test_result="Stress test completed successfully."
echo "$stress_test_result"

# Optional: Check for system updates (update package index)
print_separator
echo "Checking for System Updates:"
sudo apt update

# Summary of Test Results
print_separator
echo "Zusammenfassung der Testergebnisse:"
echo ""
echo "OS Information:"
if command -v lsb_release &> /dev/null; then
  lsb_release -d
else
  grep '^PRETTY_NAME' /etc/os-release
fi
echo ""
echo "Uptime:"
uptime -p
echo ""
echo "Disk Usage (Root Partition):"
df -h / | tail -1
echo ""
echo "Memory Usage (RAM):"
free -h | grep Mem
echo ""
echo "CPU Load Averages:"
echo "$cpu_load" | awk -F'load average:' '{print $2}'
echo ""
echo "Network Test:"
echo "$net_status"
echo ""
echo "Firewall Status:"
if command -v ufw &> /dev/null; then
  sudo ufw status | head -n 1
else
  echo "ufw not installed."
fi
echo ""
echo "Open Ports (first 5 lines):"
echo "$open_ports" | head -n 5
echo ""
echo "Services Summary:"
echo -e "$services_status" | head -n 15
echo ""
echo "$stress_test_result"
echo ""
print_separator
echo "Ubuntu Server Functionality and Stress Test Completed."
