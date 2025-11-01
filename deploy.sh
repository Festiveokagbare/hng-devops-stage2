#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
PROJECT_DIR="$HOME/backend-partA"              # where repo will be cloned
REPO_URL="https://github.com/Festiveokagbare/hng-devops-stage2.git"
BRANCH="${BRANCH:-main}"                      # branch to deploy
ENV_FILE=".env"                               # copy .env.example to .env if missing
NGINX_DEFAULT_PORT=8080

# === INSTALL DEPENDENCIES ===
echo "[INFO] Installing required packages..."
sudo apt-get update
sudo apt-get install -y docker.io git curl

# Install docker-compose plugin if docker-compose binary not found
if ! command -v docker-compose &>/dev/null; then
    echo "[INFO] Installing docker-compose plugin..."
    sudo apt-get install -y docker-compose-plugin
fi

# Use the available docker compose command
if command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    DOCKER_COMPOSE_CMD="docker compose"
fi

# Ensure Docker service is running
sudo systemctl enable docker
sudo systemctl start docker

# === CLONE OR UPDATE REPO ===
if [ ! -d "$PROJECT_DIR" ]; then
    echo "[INFO] Cloning repo..."
    git clone -b "$BRANCH" "$REPO_URL" "$PROJECT_DIR"
else
    echo "[INFO] Updating repo..."
    cd "$PROJECT_DIR"
    git fetch origin
    git reset --hard origin/"$BRANCH"
fi

cd "$PROJECT_DIR"

# === SETUP ENVIRONMENT ===
if [ ! -f "$ENV_FILE" ]; then
    echo "[INFO] Setting up environment variables..."
    cp .env.example "$ENV_FILE"
    echo "[INFO] Please edit $ENV_FILE if needed"
fi

# === DEPLOY ===
echo "[INFO] Starting Docker Compose services..."
$DOCKER_COMPOSE_CMD down || true
$DOCKER_COMPOSE_CMD build
$DOCKER_COMPOSE_CMD --env-file $ENV_FILE up -d

# === WAIT FOR NGINX AND TEST ===
NGINX_PORT=$(grep -E '^NGINX_HOST_PORT=' "$ENV_FILE" | cut -d '=' -f2 || echo "$NGINX_DEFAULT_PORT")

echo "[INFO] Waiting for services to start..."
for i in {1..10}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:"$NGINX_PORT"/version || echo "")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "[SUCCESS] Part A services running on port $NGINX_PORT"
        break
    fi
    echo "[INFO] Waiting for Nginx... ($i/10)"
    sleep 3
    if [ "$i" -eq 10 ]; then
        echo "[ERROR] Services failed to start properly"
        exit 1
    fi
done

# === PRINT PUBLIC IP ===
echo "[INFO] Your VM public IP is:"
curl -s ifconfig.me || echo "Could not retrieve IP"

echo "[INFO] Deployment complete!"
