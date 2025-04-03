#!/bin/bash

set -e

VAULT_VERSION="1.16.0"
VAULT_USER="vault"
VAULT_ADDR="https://127.0.0.1:8200"
CERT_DIR="/etc/vault/ssl"
VAULT_DATA="/opt/vault/data"
VAULT_CONFIG="/etc/vault.d"

echo "[+] Installing dependencies..."
apt update && apt install -y unzip curl gnupg2 jq ufw

echo "[+] Creating vault user and directories..."
useradd --system --home $VAULT_DATA --shell /bin/false $VAULT_USER
mkdir -p $VAULT_DATA $VAULT_CONFIG $CERT_DIR
chown -R $VAULT_USER:$VAULT_USER $VAULT_DATA

echo "[+] Downloading Vault $VAULT_VERSION..."
cd /tmp
curl -O https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip vault_${VAULT_VERSION}_linux_amd64.zip
install -o root -g root -m 0755 vault /usr/local/bin/vault

echo "[+] Creating TLS certificates..."
openssl req -newkey rsa:4096 -nodes -keyout $CERT_DIR/vault.key \
  -x509 -days 365 -out $CERT_DIR/vault.crt -subj "/CN=localhost"
chown -R $VAULT_USER:$VAULT_USER $CERT_DIR
chmod 600 $CERT_DIR/vault.*

echo "[+] Writing Vault config..."
cat <<EOF > $VAULT_CONFIG/vault.hcl
ui = true
disable_mlock = true

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_cert_file = "$CERT_DIR/vault.crt"
  tls_key_file  = "$CERT_DIR/vault.key"
}

storage "file" {
  path = "$VAULT_DATA"
}

api_addr = "$VAULT_ADDR"
cluster_addr = "https://127.0.0.1:8201"
EOF

chown -R $VAULT_USER:$VAULT_USER $VAULT_CONFIG
chmod 640 $VAULT_CONFIG/vault.hcl

echo "[+] Creating systemd service..."
cat <<EOF > /etc/systemd/system/vault.service
[Unit]
Description=HashiCorp Vault
After=network-online.target
Wants=network-online.target

[Service]
User=$VAULT_USER
Group=$VAULT_USER
ExecStart=/usr/local/bin/vault server -config=$VAULT_CONFIG/vault.hcl
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
CapabilityBoundingSet=CAP_IPC_LOCK
AmbientCapabilities=CAP_IPC_LOCK

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Enabling firewall..."
ufw allow 8200/tcp
ufw enable

echo "[+] Starting Vault..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable vault
systemctl start vault

echo "[✓] Vault is running! Run 'vault status' to check."
echo "-> Init Vault with:"
echo "   vault operator init"
echo "-> Then unseal it with:"
echo "   vault operator unseal <key>"
