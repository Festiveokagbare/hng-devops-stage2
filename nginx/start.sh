#!/bin/sh
set -e

TEMPLATE="/etc/nginx/templates/nginx.conf.template"
OUT="/etc/nginx/nginx.conf"

# Default values
: "${ACTIVE_POOL:=blue}"

echo "Rendering nginx.conf. ACTIVE_POOL=${ACTIVE_POOL}"

# Copy template to actual nginx.conf
envsubst '$ACTIVE_POOL' < "$TEMPLATE" > "$OUT"

echo "--- generated nginx.conf ---"
tail -n 20 "$OUT"
echo "----------------------------"

# Start Nginx in foreground
exec nginx -g 'daemon off;'
