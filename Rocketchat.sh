#!/bin/bash
# Bash script to automatically set up a Rocket.Chat server

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or use sudo."
  exit 1
fi

echo "Welcome to the Rocket.Chat auto setup script!"

# Prompt for configuration values
read -p "Enter the ROOT_URL for Rocket.Chat (e.g., http://chat.example.com): " ROOT_URL
if [ -z "$ROOT_URL" ]; then
  echo "ROOT_URL cannot be empty. Exiting."
  exit 1
fi

read -p "Enter the port for Rocket.Chat [default: 3000]: " PORT
PORT=${PORT:-3000}

read -p "Enter the MongoDB URL [default: mongodb://localhost:27017/rocketchat]: " MONGO_URL
MONGO_URL=${MONGO_URL:-mongodb://localhost:27017/rocketchat}

echo "Using the following configuration:"
echo "ROOT_URL: $ROOT_URL"
echo "PORT: $PORT"
echo "MONGO_URL: $MONGO_URL"

# Update package lists and install dependencies
echo "Updating system and installing required packages..."
apt-get update
apt-get install -y curl build-essential

# Install Node.js (using NodeSource for a stable version)
curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
apt-get install -y nodejs

# (Optional) Install MongoDB if not already installed - this example assumes MongoDB is already set up.
# Uncomment below lines if you wish to install MongoDB:
# apt-get install -y mongodb

# Create a directory for Rocket.Chat installation
INSTALL_DIR="/opt/rocket.chat"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Download the latest Rocket.Chat release
echo "Downloading the latest Rocket.Chat release..."
curl -L https://releases.rocket.chat/latest/download -o rocket.chat.tgz

# Extract the downloaded archive
tar -xzf rocket.chat.tgz
# The archive contains a directory named "bundle"
mv bundle Rocket.Chat

# Install Rocket.Chat server dependencies
echo "Installing Rocket.Chat server dependencies..."
cd Rocket.Chat/programs/server
npm install

# Go back to the installation directory
cd $INSTALL_DIR

# Create a system user for Rocket.Chat if it doesn't exist
if ! id -u rocketchat >/dev/null 2>&1; then
  echo "Creating rocketchat user..."
  useradd -M -s /bin/false rocketchat
fi

# Change ownership of the installation directory
chown -R rocketchat:rocketchat $INSTALL_DIR/Rocket.Chat

# Create a systemd service file for Rocket.Chat
SERVICE_FILE="/lib/systemd/system/rocketchat.service"
cat > $SERVICE_FILE <<EOL
[Unit]
Description=The Rocket.Chat Server
After=network.target

[Service]
ExecStart=/usr/bin/node $INSTALL_DIR/Rocket.Chat/main.js
Environment=ROOT_URL=$ROOT_URL
Environment=MONGO_URL=$MONGO_URL
Environment=PORT=$PORT
Restart=always
User=rocketchat
Group=rocketchat
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=rocketchat
LimitNOFILE=49152

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and start Rocket.Chat
echo "Reloading systemd daemon and starting Rocket.Chat service..."
systemctl daemon-reload
systemctl start rocketchat
systemctl enable rocketchat

echo "Rocket.Chat setup is complete!"
echo "Visit $ROOT_URL:$PORT to access your Rocket.Chat server."
