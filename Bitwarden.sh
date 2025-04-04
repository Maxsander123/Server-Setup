#!/bin/bash
# Dieses Skript richtet eine einfache KeyVault Website auf einem Debian Server ein.
# Es installiert Nginx, erstellt das Web-Verzeichnis, legt eine Beispiel-index.html an
# und richtet einen Nginx-Serverblock ein. Optional wird auch Let’s Encrypt (Certbot) für SSL angeboten.

# Bei Fehler sofort abbrechen
set -e

# Prüfen, ob als root ausgeführt
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führe das Skript als root oder mit sudo aus."
  exit 1
fi

# Domainnamen interaktiv abfragen
read -p "Bitte gib den Domainnamen ein (z.B. example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
  echo "Es wurde kein Domainname eingegeben. Abbruch."
  exit 1
fi

WEB_DIR="/var/www/$DOMAIN"

echo "Aktualisiere die Paketlisten..."
apt update

echo "Installiere Nginx und Certbot..."
apt install -y nginx certbot python3-certbot-nginx

echo "Erstelle das Web-Verzeichnis unter $WEB_DIR..."
mkdir -p "$WEB_DIR"
# Setze den Eigentümer auf den aktuellen SUDO_USER, passe dies ggf. an
chown -R "$SUDO_USER":"$SUDO_USER" "$WEB_DIR"

echo "Erstelle eine Beispiel-index.html..."
cat > "$WEB_DIR/index.html" <<EOF
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <title>KeyVault Website</title>
</head>
<body>
  <h1>Willkommen bei der KeyVault Website</h1>
  <p>Diese Seite wird von Nginx auf einem Debian Server gehostet.</p>
</body>
</html>
EOF

echo "Erstelle den Nginx-Serverblock für $DOMAIN..."
NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"
cat > "$NGINX_CONFIG" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root $WEB_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

echo "Aktiviere die Nginx-Konfiguration..."
ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/

echo "Teste die Nginx-Konfiguration..."
nginx -t

echo "Starte Nginx neu..."
systemctl reload nginx

# Optionale Einrichtung eines SSL-Zertifikats mit Certbot
read -p "Möchtest du ein SSL-Zertifikat mit Certbot einrichten? (y/n): " SETUP_SSL
if [ "$SETUP_SSL" == "y" ]; then
    certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN"
fi

echo "Die KeyVault Website für $DOMAIN wurde erfolgreich eingerichtet!"
