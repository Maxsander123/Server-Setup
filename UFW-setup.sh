#!/bin/bash
# This script installs and configures UFW.
# It lists listening ports along with the associated service (if detected),
# prompts the user if they want to allow standard ports (SSH, HTTP, HTTPS),
# and then asks for each detected port if it should be allowed through the firewall.

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo or as root."
    exit 1
fi

# Check if UFW is installed; if not, install it.
if ! command -v ufw &> /dev/null; then
    echo "UFW not found. Installing UFW..."
    apt-get update && apt-get install -y ufw
fi

# Check if netstat is available (from net-tools). If not, install net-tools.
if ! command -v netstat &> /dev/null; then
    echo "netstat command not found. Installing net-tools..."
    apt-get update && apt-get install -y net-tools
fi

# Ask the user about allowing standard ports.
read -p "Do you want to allow standard ports (SSH, HTTP, HTTPS)? (y/n): " allow_std
if [[ "$allow_std" =~ ^[Yy]$ ]]; then
    echo "Allowing standard ports..."
    ufw allow ssh
    ufw allow http
    ufw allow https
fi

# Detect listening ports along with their associated service names.
echo "Detecting listening ports and their services..."
# Using netstat with -p to include the process information.
# The awk script extracts the port (from Local Address) and the service name (from PID/Program name).
LISTENING_SERVICES=$(netstat -tulnp | awk 'NR>2 {
    # Split the Local Address by colon to get the port number.
    split($4, addr, ":");
    port = addr[length(addr)];
    
    # Extract service name from the "PID/Program name" column if available.
    service = "Unknown"
    if ($7 != "" && $7 != "-") {
        split($7, proc, "/");
        if (length(proc) > 1) {
            service = proc[2]
        }
    }
    if (port ~ /^[0-9]+$/) {
        print port, service
    }
}' | sort -n | uniq)

echo "The following listening ports and their services were detected:"
echo "$LISTENING_SERVICES"
echo ""

# Loop over each detected port and ask the user whether to allow it.
while read -r port service; do
    read -p "Do you want to allow incoming traffic on port $port (service: $service)? (y/n): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        ufw allow "$port"
    fi
done <<< "$LISTENING_SERVICES"

# Set UFW default policies.
echo "Setting default UFW policies..."
ufw default deny incoming
ufw default allow outgoing

# Enable UFW.
echo "Enabling UFW..."
ufw --force enable

echo "UFW configuration completed."
