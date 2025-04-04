#!/bin/bash
# Automatisches Setup von Vaultwarden (ehemals Bitwarden_RS)
# Dieses Skript führt folgende Schritte aus:
# 1. Systemaktualisierung
# 2. Installation von Docker und Docker Compose (falls nicht vorhanden)
# 3. Erstellung eines Arbeitsverzeichnisses für Vaultwarden
# 4. Erstellung der docker-compose.yml Datei
# 5. Starten des Vaultwarden-Containers

# Sicherstellen, dass das Skript als Root oder mit sudo ausgeführt wird
if [ "$(id -u)" -ne 0 ]; then
  echo "Bitte führe dieses Skript als root oder mit sudo aus."
  exit 1
fi

echo "System wird aktualisiert..."
apt update && apt upgrade -y

echo "Docker wird installiert (falls noch nicht vorhanden)..."
if ! command -v docker &> /dev/null; then
  apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io
fi

echo "Docker Compose wird installiert (falls noch nicht vorhanden)..."
if ! command -v docker-compose &> /dev/null; then
  curl -L "https://github.com/docker/compose/releases/download/2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

echo "Erstelle Arbeitsverzeichnis für Vaultwarden..."
mkdir -p /opt/vaultwarden
cd /opt/vaultwarden

echo "Erstelle docker-compose.yml..."
cat > docker-compose.yml <<'EOF'
version: "3"
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    volumes:
      - ./vw-data:/data
    ports:
      - "80:80"
EOF

echo "Starte Vaultwarden Container..."
docker-compose up -d

echo "Vaultwarden wurde erfolgreich gestartet."
echo "Du kannst jetzt über http://<Server-IP> auf deine Passwortverwaltung zugreifen."
