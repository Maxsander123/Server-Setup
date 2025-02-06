#!/bin/bash

# Ensure the script runs as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo su or sudo bash)"
  exit 1
fi

# Update and upgrade the system
echo "Updating system..."
apt update && apt upgrade -y

# Install essential utilities
echo "Installing essential tools..."
apt install -y btop htop mc wget curl git unzip tar zip nano vim tmux screen software-properties-common \
  build-essential net-tools ufw fail2ban rsync openssh-server sudo lsof ltrace strace gdb tcpdump \
  sysstat iproute2 iputils-ping dnsutils traceroute whois nmap telnet socat iperf3 jq fzf ripgrep \
  neofetch tree cron logrotate psmisc bash-completion sudo bash unzip locate gzip bzip2 \
  apache2-utils aria2 ffmpeg pv ngrep multitail glances duf duff progress ncdu mtr zsh \
  ca-certificates certbot python3-certbot-apache python3-certbot-nginx dnsmasq wireguard openvpn \
  libssl-dev libffi-dev python3-pip python3-venv libapache2-mod-security2 clamav rkhunter \
  smartmontools exfat-fuse exfat-utils syslog-ng logwatch monit supervisor fail2ban auditd \
  iotop vnstat bmon iftop atop sysdig slurm logstash metricbeat filebeat packetbeat beats \
  ethtool speedtest-cli vnstat glusterfs-client borgbackup restic duplicity nfs-common cifs-utils \
  samba samba-client snmp snmpd snmp-mibs-downloader net-snmp nfs-kernel-server sshguard logcheck

# Clean up
echo "Cleaning up..."
apt autoremove -y && apt autoclean -y

# Enable essential services
echo "Enabling services..."
systemctl enable --now ssh ufw fail2ban

# Configure Firewall (UFW)
echo "Setting up UFW firewall..."
ufw allow OpenSSH
ufw enable

# Final message
echo "Setup complete! Reboot recommended."
