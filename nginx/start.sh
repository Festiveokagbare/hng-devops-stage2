#!/bin/sh
set -eu

TEMPLATE="/etc/nginx/templates/nginx.conf.template"
OUT="/etc/nginx/conf.d/default.conf"

# Must have ACTIVE_POOL and APP_PORT env vars
: "${ACTIVE_POOL:=blue}"
: "${APP_PORT:=3000}"

echo "Starting nginx templating. ACTIVE_POOL=${ACTIVE_POOL}, APP_PORT=${APP_PORT}"

# Generate an upstream block depending on ACTIVE_POOL
if [ "$ACTIVE_POOL" = "blue" ]; then
  PRIMARY="app_blue:${APP_PORT} max_fails=1 fail_timeout=3s"
  BACKUP="app_green:${APP_PORT} backup"
else
  PRIMARY="app_green:${APP_PORT} max_fails=1 fail_timeout=3s"
  BACKUP="app_blue:${APP_PORT} backup"
fi

# Replace tokens in template
sed "s|__PRIMARY_SERVER__|${PRIMARY}|g; s|__BACKUP_SERVER__|${BACKUP}|g; s|__APP_PORT__|${APP_PORT}|g" "$TEMPLATE" > "$OUT"

# show the generated config for debugging
echo "--- generated nginx conf ---"
cat "$OUT"
echo "---------------------------"

# Start nginx in foreground
exec nginx -g "daemon off;"
