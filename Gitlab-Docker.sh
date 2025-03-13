#!/bin/bash
set -e

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Docker is not installed. Please install Docker before running this script."
  exit 1
fi

echo "GitLab Docker installation script"

# Prompt for user inputs with defaults
read -p "Enter the container name [gitlab]: " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-gitlab}

read -p "Enter the hostname for GitLab [gitlab.example.com]: " HOSTNAME
HOSTNAME=${HOSTNAME:-gitlab.example.com}

read -p "Enter the host port for HTTP [80]: " PORT_HTTP
PORT_HTTP=${PORT_HTTP:-80}

read -p "Enter the host port for HTTPS [443]: " PORT_HTTPS
PORT_HTTPS=${PORT_HTTPS:-443}

read -p "Enter the host port for SSH [22]: " PORT_SSH
PORT_SSH=${PORT_SSH:-22}

read -p "Enter the GitLab Docker image (gitlab/gitlab-ce or gitlab/gitlab-ee) [gitlab/gitlab-ce]: " DOCKER_IMAGE
DOCKER_IMAGE=${DOCKER_IMAGE:-gitlab/gitlab-ce}

read -p "Enter the Docker image tag [latest]: " DOCKER_TAG
DOCKER_TAG=${DOCKER_TAG:-latest}

# Set volume paths (host directories for persistent data)
read -p "Enter the host path for GitLab config [/srv/gitlab/config]: " CONFIG_PATH
CONFIG_PATH=${CONFIG_PATH:-/srv/gitlab/config}

read -p "Enter the host path for GitLab logs [/srv/gitlab/logs]: " LOGS_PATH
LOGS_PATH=${LOGS_PATH:-/srv/gitlab/logs}

read -p "Enter the host path for GitLab data [/srv/gitlab/data]: " DATA_PATH
DATA_PATH=${DATA_PATH:-/srv/gitlab/data}

# Create directories if they don't exist
mkdir -p "$CONFIG_PATH" "$LOGS_PATH" "$DATA_PATH"

echo "Pulling Docker image ${DOCKER_IMAGE}:${DOCKER_TAG}..."
docker pull "${DOCKER_IMAGE}:${DOCKER_TAG}"

echo "Running GitLab container..."
docker run --detach \
  --hostname "$HOSTNAME" \
  --publish "${PORT_HTTPS}":443 --publish "${PORT_HTTP}":80 --publish "${PORT_SSH}":22 \
  --name "$CONTAINER_NAME" \
  --restart always \
  --volume "$CONFIG_PATH":/etc/gitlab \
  --volume "$LOGS_PATH":/var/log/gitlab \
  --volume "$DATA_PATH":/var/opt/gitlab \
  "${DOCKER_IMAGE}:${DOCKER_TAG}"

echo "GitLab is being set up in the Docker container named '$CONTAINER_NAME'."
echo "It might take a few minutes for GitLab to be fully configured on first launch."
