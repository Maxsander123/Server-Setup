#!/bin/bash
# This script updates the system and lets you choose which category of tools to install.
# It groups packages into:
#   1) CLI & Utilities
#   2) Network Tools
#   3) Security & Monitoring Tools
#   4) Development Tools
#   5) Backup Tools
#   6) All (installs every package)
#
# Run as root!

# Ensure the script runs as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo su or sudo bash)"
  exit 1
fi

# Update and upgrade the system
echo "Updating system..."
apt update && apt upgrade -y

# Define package groups

cli_tools=(
  btop htop mc wget curl git unzip tar zip nano vim tmux screen software-properties-common
  cron logrotate psmisc bash-completion locate gzip bzip2 aria2 ffmpeg pv multitail glances
  duf duff progress ncdu neofetch tree fzf ripgrep zsh
)

network_tools=(
  net-tools ufw rsync openssh-server lsof ltrace strace tcpdump sysstat iproute2 iputils-ping
  dnsutils traceroute whois nmap telnet socat iperf3 speedtest-cli vnstat mtr iftop dnsmasq
  wireguard openvpn samba samba-client snmp snmpd snmp-mibs-downloader net-snmp nfs-common
  nfs-kernel-server cifs-utils
)

security_tools=(
  fail2ban clamav rkhunter libapache2-mod-security2 auditd sshguard logcheck syslog-ng
  logwatch monit supervisor certbot python3-certbot-apache python3-certbot-nginx
)

development_tools=(
  build-essential libssl-dev libffi-dev python3-pip python3-venv gdb
)

backup_tools=(
  borgbackup restic duplicity
)

# Display selection menu
echo "Select the categories of tools to install:"
echo "  1) CLI & Utilities"
echo "  2) Network Tools"
echo "  3) Security & Monitoring Tools"
echo "  4) Development Tools"
echo "  5) Backup Tools"
echo "  6) All Tools"
read -p "Enter your choices as comma-separated numbers (e.g. 1,3,5): " choices

# Convert user input to an array (splitting on commas)
IFS=',' read -ra selected <<< "$choices"

# Initialize empty array for selected packages
packages=()

# Process each selected option
for choice in "${selected[@]}"; do
  # Remove any surrounding whitespace
  choice=$(echo "$choice" | xargs)
  case "$choice" in
    1)
      packages+=("${cli_tools[@]}")
      ;;
    2)
      packages+=("${network_tools[@]}")
      ;;
    3)
      packages+=("${security_tools[@]}")
      ;;
    4)
      packages+=("${development_tools[@]}")
      ;;
    5)
      packages+=("${backup_tools[@]}")
      ;;
    6)
      packages+=("${cli_tools[@]}" "${network_tools[@]}" "${security_tools[@]}" "${development_tools[@]}" "${backup_tools[@]}")
      # No need to check further choices if "All" is selected.
      break
      ;;
    *)
      echo "Invalid choice: $choice"
      ;;
  esac
done

# Remove duplicate package names by sorting uniquely
unique_packages=($(printf "%s\n" "${packages[@]}" | sort -u))

# Install selected packages
echo "Installing selected packages..."
apt install -y "${unique_packages[@]}"

# Clean up
echo "Cleaning up..."
apt autoremove -y && apt autoclean -y

# Enable essential services (SSH and fail2ban)
echo "Enabling essential services..."
systemctl enable --now ssh fail2ban

echo "Setup complete! A reboot is recommended."
