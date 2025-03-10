#!/bin/bash
# setup_client.sh
# This script sets up the client-side application that sends system stats to the server.

# Create the necessary directory
mkdir -p client

# Create the client Python script (client.py)
cat > client/client.py << 'EOF'
import requests
import psutil
import socket
import time
import argparse

def get_system_stats():
    stats = {
        'hostname': socket.gethostname(),
        'cpu_usage': psutil.cpu_percent(interval=1),
        'memory': psutil.virtual_memory()._asdict(),
        'load': psutil.getloadavg(),  # Returns tuple: (1min, 5min, 15min)
    }
    return stats

def send_stats(server_ip, server_port):
    url = f"http://{server_ip}:{server_port}/submit"
    data = get_system_stats()
    try:
        response = requests.post(url, json=data)
        print("Server response:", response.json())
    except Exception as e:
        print("Error sending data to server:", e)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Send system stats to the server.')
    parser.add_argument('--server', required=True, help='Server IP address')
    parser.add_argument('--port', default=5000, type=int, help='Server port (default: 5000)')
    parser.add_argument('--interval', default=60, type=int, help='Interval in seconds to send stats (default: 60)')
    args = parser.parse_args()

    while True:
        send_stats(args.server, args.port)
        time.sleep(args.interval)
EOF

echo "Client file created successfully."

# Update package lists and install required system packages (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv

# Create and activate a virtual environment inside the client directory
python3 -m venv client/venv
source client/venv/bin/activate

# Install required Python packages for the client
pip install requests psutil

# Check if a server IP was provided as the first argument.
if [ -z "$1" ]; then
  echo "Usage: $0 <server_ip> [server_port] [interval_seconds]"
  exit 1
fi

SERVER_IP="$1"
SERVER_PORT="${2:-5000}"
INTERVAL="${3:-60}"

echo "Starting client script to send stats to ${SERVER_IP}:${SERVER_PORT} every ${INTERVAL} seconds..."
python client/client.py --server "$SERVER_IP" --port "$SERVER_PORT" --interval "$INTERVAL"
