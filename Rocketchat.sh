#!/bin/bash
# Bash script to set up a Rocket.Chat server in Docker using Docker Compose

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Docker is not installed. Please install Docker first."
  exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  echo "Docker Compose is not installed. Please install Docker Compose first."
  exit 1
fi

echo "Welcome to the Rocket.Chat Docker setup script!"

# Prompt for configuration values
read -p "Enter the ROOT_URL for Rocket.Chat (e.g., http://chat.example.com): " ROOT_URL
if [ -z "$ROOT_URL" ]; then
  echo "ROOT_URL cannot be empty. Exiting."
  exit 1
fi

read -p "Enter the host port to map to Rocket.Chat [default: 3000]: " HOST_PORT
HOST_PORT=${HOST_PORT:-3000}

# Define MongoDB URLs for Rocket.Chat configuration
MONGO_URL="mongodb://mongo:27017/rocketchat?replicaSet=rs0"
MONGO_OPLOG_URL="mongodb://mongo:27017/local?replicaSet=rs0"

echo "Creating docker-compose.yml file..."
cat > docker-compose.yml <<EOL
version: "3"

services:
  rocketchat:
    image: rocketchat/rocket.chat:latest
    restart: unless-stopped
    environment:
      - PORT=3000
      - ROOT_URL=${ROOT_URL}
      - MONGO_URL=${MONGO_URL}
      - MONGO_OPLOG_URL=${MONGO_OPLOG_URL}
    ports:
      - "${HOST_PORT}:3000"
    depends_on:
      - mongo

  mongo:
    image: mongo:4.0
    restart: unless-stopped
    command: mongod --smallfiles --oplogSize 128 --replSet rs0
    volumes:
      - mongo_data:/data/db

volumes:
  mongo_data:
EOL

echo "Starting Rocket.Chat and MongoDB containers using Docker Compose..."
docker-compose up -d

echo "Rocket.Chat is being set up. Visit ${ROOT_URL}:${HOST_PORT} (after a few moments) to access your Rocket.Chat server."
