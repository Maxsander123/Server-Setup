#!/bin/bash
# Dieses Skript aktualisiert das System und erlaubt die Auswahl, welche Kategorie von Tools installiert werden soll.
# Es gruppiert Pakete in:
#   1) CLI & Utilities
#   2) Network Tools
#   3) Security & Monitoring Tools
#   4) Development Tools
#   5) Backup Tools
#   6) Additional Tools (200+ extra)
#   7) All Tools (installiert alle Pakete)
#
# Skript als root ausführen!

# Prüfe, ob das Skript als root läuft
if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root ausführen (sudo su oder sudo bash)"
  exit 1
fi

# System aktualisieren und upgraden
echo "System wird aktualisiert..."
apt update && apt upgrade -y

# Definiere die Paketgruppen

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

# Zusätzliche Tools (über 200 Pakete, „good to have“)
misc_tools=(
  apt-file aptitude autojump bc bleachbit cmatrix colordiff cowsay deborphan dconf-editor
  dos2unix dmidecode e2fsprogs exiftool figlet fortune foomatic-db-complete g++ gcc gimp
  gnome-disk-utility gnupg gparted graphviz imagemagick inxi iptables iptables-persistent
  jwhois keepassxc kmod leafpad less lnav lsscsi lynx make man-db mdadm meld mmv netcat
  netcat-openbsd nethogs ntp ntpdate ntfs-3g okular openjdk-11-jdk openjdk-8-jdk openssl
  openssh-client os-prober p7zip-full pbzip2 perl php php-cli php-curl php-mbstring pkg-config
  plocate postgresql-client powerline proot pulseaudio qemu qemu-kvm qt5-default rclone remmina
  rlwrap rsnapshot screenfetch scrot sed silversearcher-ag smartmontools smbclient sox sqlmap
  sudo sysbench tesseract-ocr terminator transmission-cli unrar upower usbutils vlc w3m watch
  weechat wput xclip xdg-utils xinput xrandr xscreensaver xserver-xorg youtube-dl zathura acpi
  arping bmon bridge-utils cbm cgroup-tools conky cpufrequtils dstat ethtool fcitx ffmpegthumbnailer
  fping gawk gh git-lfs gnome-terminal golang grsync gtkhash hddtemp iotop iperf irssi jnettop jq
  keepalived krename libcurl4-openssl-dev libxml2-utils lynis maven mediainfo minicom mlocate
  moreutils ncmpcpp nco nload nodejs npm ntfs-config numlockx openconnect pavucontrol parcellite
  pass pcmciautils perl-modules phpmyadmin pidgin pkexec plank poppler-utils powertop pulsemixer
  python-is-python3 qbittorrent qpdf qutebrowser r-base rdesktop realpath simple-scan slurm
  speedcrunch sqlite3 stacer subversion synaptic sysvbanner tilda tmuxinator totem transmission-gtk
  ttf-mscorefonts-installer unison vagrant valgrind virtualbox virt-manager watchdog wine
  winetricks xarchiver xdotool xfce4-terminal xsel xserver-xorg-input-all xserver-xorg-video-all
  yelp zenity zram-tools apt-transport-https libpq-dev python3-dev python3-setuptools python3-wheel
)

# Anzeige des Auswahlmenüs
echo "Wähle die Kategorien der zu installierenden Tools aus:"
echo "  1) CLI & Utilities"
echo "  2) Network Tools"
echo "  3) Security & Monitoring Tools"
echo "  4) Development Tools"
echo "  5) Backup Tools"
echo "  6) Additional Tools (200+ extra)"
echo "  7) All Tools (alle Kategorien)"
read -p "Gib deine Auswahl als komma-getrennte Zahlen ein (z.B. 1,3,5): " choices

# Umwandlung der Benutzereingabe in ein Array (Trennung bei Kommas)
IFS=',' read -ra selected <<< "$choices"

# Initialisiere leeres Array für die zu installierenden Pakete
packages=()

# Verarbeite jede ausgewählte Option
for choice in "${selected[@]}"; do
  # Entferne führende und nachfolgende Leerzeichen
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
      packages+=("${misc_tools[@]}")
      ;;
    7)
      packages+=("${cli_tools[@]}" "${network_tools[@]}" "${security_tools[@]}" \
                   "${development_tools[@]}" "${backup_tools[@]}" "${misc_tools[@]}")
      # Bei "All Tools" ist keine weitere Verarbeitung notwendig.
      break
      ;;
    *)
      echo "Ungültige Auswahl: $choice"
      ;;
  esac
done

# Entferne doppelte Paketnamen durch sortieren und unique
unique_packages=($(printf "%s\n" "${packages[@]}" | sort -u))

# Installiere die ausgewählten Pakete
echo "Installiere die ausgewählten Pakete..."
apt install -y "${unique_packages[@]}"

# Aufräumen
echo "Aufräumen..."
apt autoremove -y && apt autoclean -y

# Aktiviere essentielle Dienste (SSH und fail2ban)
echo "Aktiviere essentielle Dienste..."
systemctl enable --now ssh fail2ban

echo "Setup abgeschlossen! Ein Neustart wird empfohlen."
