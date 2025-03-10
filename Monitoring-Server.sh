#!/bin/bash
# setup_server.sh
# This script sets up the server-side website that collects client data.

# Create necessary directories
mkdir -p server/templates

# Create the Flask application file (server.py)
cat > server/server.py << 'EOF'
from flask import Flask, request, jsonify, render_template
import datetime

app = Flask(__name__)

# In-memory store for client data
client_data = {}

@app.route('/submit', methods=['POST'])
def submit_data():
    data = request.get_json()
    if not data:
        return jsonify({'status': 'error', 'message': 'No data provided'}), 400
    hostname = data.get('hostname', 'unknown')
    data['timestamp'] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    client_data[hostname] = data
    return jsonify({'status': 'success'}), 200

@app.route('/')
def dashboard():
    return render_template('dashboard.html', data=client_data)

if __name__ == '__main__':
    # Listen on all interfaces at port 5000
    app.run(host='0.0.0.0', port=5000)
EOF

# Create the HTML template (dashboard.html)
cat > server/templates/dashboard.html << 'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Client System Stats Dashboard</title>
  <style>
    table {
      width: 80%;
      margin: auto;
      border-collapse: collapse;
    }
    th, td {
      border: 1px solid #333;
      padding: 8px;
      text-align: left;
    }
    th {
      background-color: #f2f2f2;
    }
    h1 {
      text-align: center;
    }
  </style>
</head>
<body>
  <h1>Client System Stats Dashboard</h1>
  <table>
    <thead>
      <tr>
        <th>Hostname</th>
        <th>CPU Usage (%)</th>
        <th>Memory</th>
        <th>Load (1,5,15 min)</th>
        <th>Timestamp</th>
      </tr>
    </thead>
    <tbody>
      {% for hostname, stats in data.items() %}
      <tr>
        <td>{{ hostname }}</td>
        <td>{{ stats.cpu_usage if stats.cpu_usage is defined else 'N/A' }}</td>
        <td>
          {% if stats.memory is defined %}
            Total: {{ stats.memory.total }}<br>
            Used: {{ stats.memory.used }}<br>
            Available: {{ stats.memory.available }}
          {% else %}
            N/A
          {% endif %}
        </td>
        <td>
          {% if stats.load is defined %}
            {{ stats.load[0] }}, {{ stats.load[1] }}, {{ stats.load[2] }}
          {% else %}
            N/A
          {% endif %}
        </td>
        <td>{{ stats.timestamp if stats.timestamp is defined else 'N/A' }}</td>
      </tr>
      {% endfor %}
    </tbody>
  </table>
</body>
</html>
EOF

echo "Server files created successfully."

# Update package lists and install required system packages (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv

# Create and activate a virtual environment inside the server directory
python3 -m venv server/venv
source server/venv/bin/activate

# Install Flask in the virtual environment
pip install Flask

echo "Starting the Flask server..."
python server/server.py
