#!/bin/bash
# Ubuntu Server Functionality and Stress Test Script
# This script performs a series of basic checks on an Ubuntu server and then runs a stress test.
# Run this script with sufficient privileges (some commands require sudo).

# Function to print a separator
print_separator() {
  echo "------------------------------------------------------------"
}

# Check OS information
print_separator
echo "OS Information:"
if command -v lsb_release &> /dev/null; then
  lsb_release -a
else
  cat /etc/os-release
fi

# Check system uptime
print_separator
echo "System Uptime:"
uptime

# Check disk usage
print_separator
echo "Disk Usage:"
df -h

# Check memory usage
print_separator
echo "Memory Usage:"
free -h

# Check CPU load
print_separator
echo "CPU Load:"
top -bn1 | grep "load average:"

# Test network connectivity
print_separator
echo "Network Connectivity Test (ping google.com):"
if ping -c 4 google.com &> /dev/null; then
  echo "Network is up."
else
  echo "Network seems down or google.com is unreachable."
fi

# Check firewall status (UFW)
print_separator
echo "Firewall Status (UFW):"
if command -v ufw &> /dev/null; then
  sudo ufw status verbose
else
  echo "ufw is not installed."
fi

# Check for open ports
print_separator
echo "Open Ports:"
sudo ss -tuln

# Check critical services (SSH, Apache2, Nginx)
print_separator
for service in ssh apache2 nginx; do
  echo "Service Status: $service"
  if systemctl list-units --type=service | grep -q "$service"; then
    systemctl status "$service" --no-pager | head -n 10
  else
    echo "Service '$service' is not installed."
  fi
  echo ""
done

# Run a stress test
print_separator
echo "Running Stress Test for 60 seconds..."
# Check if 'stress' is installed; if not, install it.
if ! command -v stress &> /dev/null; then
  echo "'stress' tool is not installed. Installing..."
  sudo apt-get update && sudo apt-get install -y stress
fi

# Run the stress test (adjust parameters as needed)
stress --cpu 4 --io 2 --vm 2 --vm-bytes 128M --timeout 60s
echo "Stress test completed."

# Check for system updates (update package index)
print_separator
echo "Checking for System Updates:"
sudo apt update

print_separator
echo "Ubuntu Server Functionality and Stress Test Completed."
