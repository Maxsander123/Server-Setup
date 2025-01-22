#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Use sudo to execute it."
    exit 1
fi

# Update package lists
echo "Updating package lists..."
apt-get update -y

# Install htop
echo "Installing htop..."
apt-get install -y htop

# Install btop
echo "Installing btop..."
apt-get install -y btop

# Install mc (Midnight Commander)
echo "Installing mc..."
apt-get install -y mc

# Install Apache2
echo "Installing Apache2..."
apt-get install -y apache2

# Install nano
echo "Installing nano..."
apt-get install -y nano

# Install common tools and packages
echo "Installing common tools and packages..."
apt-get install -y curl wget git build-essential net-tools unzip zip vim tree tmux ufw

# Install monitoring software
echo "Installing monitoring software..."
apt-get install -y nagios nrpe
apt-get install -y prometheus-node-exporter grafana

# Print completion message
echo "Installation of tools, packages, and monitoring software is complete."

