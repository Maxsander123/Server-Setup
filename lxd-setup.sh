#!/bin/bash
set -e # Bricht das Skript bei einem Fehler sofort ab

# --- KONFIGURATION (Angepasst mit Ihren Daten) ---
DOMAIN="lxd.mtlgroup.tech"
EMAIL="mj_sander@web.de"
ROUTED_IPV6_SUBNET="2a03:4000:6c:3b6::/64"
IPV6_GATEWAY="2a03:4000:6c:3b6::1/64" 
# --- ENDE DER KONFIGURATION ---


echo "===== Schritt 0: System-Vorbereitung ====="
apt-get update
apt-get upgrade -y
apt-get install -y snapd git nginx certbot python3-certbot-nginx lvm2 zfsutils-linux jq python3-venv python3-pip build-essential

echo "===== Schritt 1: LXD Installation und Initialisierung ====="
snap install lxd --channel=latest/stable
export PATH=$PATH:/snap/bin

# Erstelle die preseed-Konfigurationsdatei für LXD
cat > /root/lxd-preseed.yaml <<EOF
config: {}
networks:
- name: lxdbr0
  type: bridge
  config:
    ipv4.address: auto
    ipv4.nat: "true"
    ipv6.address: ${IPV6_GATEWAY}
    ipv6.nat: "false"
    ipv6.routing: "true"
profiles:
- name: default
  devices:
    eth0:
      name: eth0
      network: lxdbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
cluster: null
EOF

echo "Warte 5 Sekunden, damit der LXD-Daemon vollständig startet..."
sleep 5
lxd init --preseed < /root/lxd-preseed.yaml


echo "===== Schritt 2: Automatisierte Speicher-Einrichtung (für Ein-Platten-Systeme optimiert) ====="
# Da es keine ungenutzten Partitionen gibt, erstellen wir einen ZFS-Pool, der eine Datei auf dem Root-Dateisystem nutzt.
# Dies ist die Standardmethode für Systeme mit nur einer Festplatte.
echo "INFO: Erstelle einen 30GB ZFS-Pool namens 'default' auf dem Root-Dateisystem."
lxc storage create default zfs size=30GB

lxc profile device set default root pool default
echo "LXD Storage Pool 'default' wurde erfolgreich eingerichtet."


echo "===== Schritt 3 & 4: NGINX, Certbot und LXDUi Installation (mit allen Korrekturen) ====="
echo "Installiere LXDUi..."
useradd --system --shell /bin/false lxdui || echo "Benutzer 'lxdui' existiert bereits."
git clone https://github.com/AdaptiveScale/lxdui.git /opt/lxdui
python3 -m venv /opt/lxdui/venv
/opt/lxdui/venv/bin/pip install --upgrade pip
/opt/lxdui/venv/bin/pip install -r /opt/lxdui/requirements.txt
/opt/lxdui/venv/bin/pip install gunicorn

# KORREKTUR: Setze die korrekten Berechtigungen für das gesamte Verzeichnis
chown -R lxdui:lxdui /opt/lxdui

# KORREKTUR: Erstelle den systemd-Service mit dem richtigen Gunicorn-Befehl
cat > /etc/systemd/system/lxdui.service <<EOF
[Unit]
Description=LXDUI - Web UI for LXD
After=network.target

[Service]
User=lxdui
Group=lxdui
WorkingDirectory=/opt/lxdui
# Der korrekte Startbefehl, der auf das 'app'-Modul verweist und --chdir verwendet
ExecStart=/opt/lxdui/venv/bin/gunicorn --workers 4 --bind 127.0.0.1:5000 --chdir /opt/lxdui app:create_app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now lxdui

LXDUI_DOMAIN="lxdui.${DOMAIN}"
cat > "/etc/nginx/sites-available/${LXDUI_DOMAIN}" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${LXDUI_DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

ln -sf "/etc/nginx/sites-available/${LXDUI_DOMAIN}" "/etc/nginx/sites-enabled/"
nginx -t
systemctl reload nginx

echo "Fordere SSL-Zertifikat für ${LXDUI_DOMAIN} an..."
certbot --nginx --agree-tos --redirect --non-interactive -m "${EMAIL}" -d "${LXDUI_DOMAIN}"


echo "===== Schritt 5: Automatisierung für neue Container einrichten ====="
mkdir -p /root/lxd-automation
cat > /root/lxd-automation/nginx-template.conf <<EOF
server {
    server_name __CONTAINER_NAME__.__DOMAIN__;
    location / {
        proxy_pass http://[__IPV6_ADDRESS__]:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    listen [::]:443 ssl ipv6only=on;
    listen 443 ssl;
    ssl_certificate /etc/letsencrypt/live/__CONTAINER_NAME__.__DOMAIN__/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/__CONTAINER_NAME__.__DOMAIN__/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}
server {
    listen 80;
    listen [::]:80;
    server_name __CONTAINER_NAME__.__DOMAIN__;
    return 301 https://\$host\$request_uri;
}
EOF

cat > /root/lxd-automation/lxd-proxy-automation.sh <<EOF
#!/bin/bash
set -e
DOMAIN="${DOMAIN}"
EMAIL="${EMAIL}"
TEMPLATE_FILE="/root/lxd-automation/nginx-template.conf"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
CERTBOT_LIVE_DIR="/etc/letsencrypt/live"
CONFIG_CHANGED=0
lxc list --format json | jq -c '.[] | select(.state.status == "Running")' | while read -r container_json; do
    NAME=\$(echo "\$container_json" | jq -r '.name')
    FULL_DOMAIN="\${NAME}.\${DOMAIN}"
    CONFIG_FILE="\${NGINX_SITES_AVAILABLE}/\${FULL_DOMAIN}.conf"
    if [ -d "\${CERTBOT_LIVE_DIR}/\${FULL_DOMAIN}" ] && [ -f "\$CONFIG_FILE" ]; then continue; fi
    echo "Verarbeite neuen Container: \$NAME"
    CONFIG_CHANGED=1
    IPV6=\$(echo "\$container_json" | jq -r '.state.network.eth0.addresses[] | select(.family == "inet6" and .scope == "global") | .address')
    if [ -z "\$IPV6" ]; then echo "WARNUNG: Konnte keine globale IPv6 für Container \$NAME finden. Überspringe."; continue; fi
    echo "  -> IPv6: \$IPV6"; echo "  -> Domain: \$FULL_DOMAIN"
    TEMP_CONFIG_FILE="\${CONFIG_FILE}.tmp"
    cat > \$TEMP_CONFIG_FILE <<EOT
server { listen 80; listen [::]:80; server_name \${FULL_DOMAIN}; location /.well-known/acme-challenge/ { root /var/www/html; } }
EOT
    ln -sf "\$TEMP_CONFIG_FILE" "\${NGINX_SITES_ENABLED}/\${FULL_DOMAIN}.conf"
    nginx -t && systemctl reload nginx
    sleep 2
    mkdir -p /var/www/html
    if certbot certonly --webroot -w /var/www/html --agree-tos --non-interactive -m "\${EMAIL}" -d "\${FULL_DOMAIN}"; then
        echo "Zertifikat für \${FULL_DOMAIN} erfolgreich erhalten."
        sed -e "s/__CONTAINER_NAME__/\${NAME}/g" -e "s/__DOMAIN__/\${DOMAIN}/g" -e "s/__IPV6_ADDRESS__/\${IPV6}/g" "\$TEMPLATE_FILE" > "\$CONFIG_FILE"
        ln -sf "\$CONFIG_FILE" "\${NGINX_SITES_ENABLED}/\${FULL_DOMAIN}.conf"
        rm -f "\$TEMP_CONFIG_FILE"
    else
        echo "FEHLER: Zertifikatsanforderung für \${FULL_DOMAIN} fehlgeschlagen."
        rm -f "\$TEMP_CONFIG_FILE" "\${NGINX_SITES_ENABLED}/\${FULL_DOMAIN}.conf"
    fi
done
if [ \$CONFIG_CHANGED -eq 1 ]; then echo "Teste NGINX und lade neu."; nginx -t && systemctl reload nginx; fi
echo "LXD Proxy Automation abgeschlossen."
EOF

chmod +x /root/lxd-automation/lxd-proxy-automation.sh

cat > /etc/systemd/system/lxd-proxy.service <<EOF
[Unit]
Description=LXD NGINX & SSL Proxy Automation
[Service]
Type=oneshot
ExecStart=/root/lxd-automation/lxd-proxy-automation.sh
EOF

cat > /etc/systemd/system/lxd-proxy.timer <<EOF
[Unit]
Description=Run LXD proxy automation every 5 minutes
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Unit=lxd-proxy.service
[Install]
WantedBy=timers.target
EOF

systemctl enable --now lxd-proxy.timer
systemctl start lxd-proxy.service

echo "===== SETUP ABGESCHLOSSEN ====="
echo "Dein LXD-Host ist jetzt konfiguriert."
echo "LXDUi sollte jetzt erreichbar sein unter: https://lxdui.${DOMAIN}"
echo "Neue Container werden automatisch innerhalb von 5 Minuten mit einer Subdomain und SSL versorgt."
echo "Beispiel: Führe 'lxc launch ubuntu:22.04 web1' aus."
