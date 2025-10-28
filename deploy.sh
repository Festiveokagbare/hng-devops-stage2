#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG ---
PROJECT_DIR="$HOME/backend-partA"   # where repo will be cloned
REPO_URL="https://github.com/Festiveokagbare/hng-devops-stage2.git"
BRANCH="${BRANCH:-main}"            # branch to deploy
ENV_FILE=".env"                     # copy .env.example to .env if missing

# --- INSTALL DEPENDENCIES ---
echo "[INFO] Installing required packages..."
sudo apt-get update
sudo apt-get install -y docker.io docker-compose git curl

# Ensure Docker service is running
sudo systemctl enable docker
sudo systemctl start docker

# --- CLONE OR UPDATE REPO ---
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

# --- SETUP ENV ---
if [ ! -f "$ENV_FILE" ]; then
    echo "[INFO] Setting up environment variables..."
    cp .env.example "$ENV_FILE"
    echo "[INFO] Edit $ENV_FILE if needed"
fi

# --- DEPLOY ---
echo "[INFO] Starting Docker Compose services..."
sudo docker-compose down || true
sudo docker-compose build
sudo docker-compose up -d

# --- NGINX TEST ---
echo "[INFO] Waiting for services to start..."
sleep 5

NGINX_PORT=$(grep NGINX_HOST_PORT "$ENV_FILE" | cut -d '=' -f2)
if curl -s -o /dev/null -w "%{http_code}" http://localhost:"$NGINX_PORT"/version | grep -q 200; then
    echo "[SUCCESS] Part A services running on port $NGINX_PORT"
else
    echo "[ERROR] Services failed to start properly"
    exit 1
fi

# --- PRINT PUBLIC IP ---
echo "[INFO] Your VM public IP is:"
curl -s ifconfig.me || echo "Could not retrieve IP"

echo "[INFO] Deployment complete!"