# watcher/Dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# install procps so pgrep exists (healthcheck uses pgrep)
RUN apt-get update && apt-get install -y procps && rm -rf /var/lib/apt/lists/*

COPY watcher.py .

ENV NGINX_LOG=/var/log/nginx/access.log \
    ERROR_RATE_THRESHOLD=2 \
    WINDOW_SIZE=200 \
    ALERT_COOLDOWN_SEC=300 \
    MAINTENANCE_MODE=false

# Create non-root user for security (optional)
RUN useradd --create-home --shell /bin/bash watcheruser || true
USER watcheruser

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD pgrep -f watcher.py > /dev/null || exit 1

CMD ["python3", "watcher.py"]
