#!/bin/bash
# -------------------------------------------------------------------
# Mailserver Setup Script (Terminal-Version)
# Installiert und konfiguriert Postfix, Dovecot und Webmin
#
# Für Debian/Ubuntu basierte Systeme.
# Bitte vor Einsatz in Produktionsumgebungen testen!
# -------------------------------------------------------------------

# Überprüfen, ob das Skript als root ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript als root (oder mit sudo) aus!"
  exit 1
fi

# Paketlisten aktualisieren
echo "Aktualisiere Paketlisten..."
apt-get update

# Notwendige Pakete installieren
echo "Installiere erforderliche Pakete (Postfix, Dovecot, wget, gnupg2)..."
apt-get install -y postfix dovecot-imapd dovecot-pop3d wget gnupg2

# --- Benutzereingaben im Terminal ---

# Domainname abfragen
read -p "Bitte geben Sie den Domainnamen für den Mailserver ein (z.B. example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "Der Domainname darf nicht leer sein. Abbruch!"
    exit 1
fi

# Administrator E-Mail abfragen
read -p "Bitte geben Sie die Administrator-E-Mail-Adresse ein (z.B. admin@example.com): " ADMIN_EMAIL
if [ -z "$ADMIN_EMAIL" ]; then
    echo "Die Admin-E-Mail darf nicht leer sein. Abbruch!"
    exit 1
fi

# --- Konfiguration von Postfix ---

POSTFIX_MAIN_CF="/etc/postfix/main.cf"
echo "Sichere die aktuelle Postfix-Konfiguration in ${POSTFIX_MAIN_CF}.bak..."
cp "$POSTFIX_MAIN_CF" "${POSTFIX_MAIN_CF}.bak"

echo "Passe die Postfix-Konfiguration an..."
postconf -e "myhostname = mail.$DOMAIN"
postconf -e "mydomain = $DOMAIN"
postconf -e "myorigin = \$mydomain"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"
postconf -e "relayhost ="
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = ipv4"
postconf -e "home_mailbox = Maildir/"

echo "Starte Postfix neu..."
systemctl restart postfix

# --- Konfiguration von Dovecot ---

# Hier wird davon ausgegangen, dass Dovecot Maildir verwendet.
echo "Starte Dovecot neu..."
systemctl restart dovecot

# --- Installation von Webmin ---

echo "Füge das Webmin-Repository hinzu..."
cat <<EOF > /etc/apt/sources.list.d/webmin.list
deb http://download.webmin.com/download/repository sarge contrib
EOF

echo "Importiere den Webmin GPG-Schlüssel..."
wget -qO - http://www.webmin.com/jcameron-key.asc | apt-key add -

echo "Aktualisiere Paketlisten..."
apt-get update

echo "Installiere Webmin..."
apt-get install -y webmin

# Ermitteln der Server-IP (erste gefundene IP-Adresse)
SERVER_IP=$(hostname -I | awk '{print $1}')

# --- Abschlussmeldung ---

echo "-----------------------------------------------------"
echo "Mailserver Setup abgeschlossen!"
echo "Postfix und Dovecot sind eingerichtet."
echo "Webmin wurde installiert und ist erreichbar unter:"
echo "https://$SERVER_IP:10000"
echo ""
echo "Bitte verwenden Sie die entsprechenden Zugangsdaten, um sich in Webmin anzumelden."
echo "Weitere Anpassungen an der Konfiguration können direkt in Webmin oder in den Konfigurationsdateien erfolgen."
echo "-----------------------------------------------------"

exit 0
