# ===============================
# Stage 3 — Observability & Alerts
# ===============================

# Use the official Nginx base image
FROM nginx:1.27-alpine

# Maintainer info
LABEL maintainer="Festus Okagbare <devops@qefas.com>" \
      description="Blue/Green Failover NGINX with Observability and Slack Alert Watcher" \
      version="3.0"

# Environment variable — will be substituted into nginx.conf.template
ENV ACTIVE_POOL=blue

# Copy the template configuration file
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# Render the final NGINX config file using envsubst (from gettext)
RUN apk add --no-cache gettext \
 && envsubst '${ACTIVE_POOL}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf \
 && mkdir -p /var/log/nginx

# Expose HTTP port
EXPOSE 80

# Default command
CMD ["nginx", "-g", "daemon off;"]
