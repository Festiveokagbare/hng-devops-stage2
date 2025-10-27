#!/bin/bash
set -euo pipefail

# Loads variables from .env (if present)
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

NGINX_URL="http://localhost:${NGINX_HOST_PORT:-8080}"
BLUE_DIRECT="http://localhost:${BLUE_HOST_PORT:-8081}"
GREEN_DIRECT="http://localhost:${GREEN_HOST_PORT:-8082}"

ACTIVE_POOL="${ACTIVE_POOL:-blue}"
APP_PORT="${PORT:-3000}"

TEST_DURATION=10
SLEEP_BEFORE_LOOP=1

echo "NGINX: ${NGINX_URL}"
echo "Blue direct: ${BLUE_DIRECT}"
echo "Green direct: ${GREEN_DIRECT}"
echo "Active pool: ${ACTIVE_POOL}"

# ------------------------------
# 1) Baseline check
# ------------------------------
echo "Baseline check (expecting active pool responses)..."

resp_headers=$(mktemp)
status=$(curl -s -D "$resp_headers" -o /dev/null -w "%{http_code}" "${NGINX_URL}/version")
apppool=$(grep -i '^X-App-Pool:' "$resp_headers" | awk '{print tolower($2)}' | tr -d '\r')
release=$(grep -i '^X-Release-Id:' "$resp_headers" | awk '{print $2}' | tr -d '\r')

echo "Status: $status, X-App-Pool: ${apppool:-N/A}, X-Release-Id: ${release:-N/A}"

if [ "$status" != "200" ]; then
    echo "Baseline failed: non-200 from nginx"
    exit 1
fi

if [ -z "$apppool" ]; then
    echo "Baseline failed: missing X-App-Pool header"
    exit 1
fi

if [ "$apppool" != "$ACTIVE_POOL" ]; then
    echo "Baseline failed: expected X-App-Pool=$ACTIVE_POOL but got $apppool"
    exit 1
fi

echo "Baseline OK"

# ------------------------------
# 2) Trigger chaos
# ------------------------------
if [ "$ACTIVE_POOL" = "blue" ]; then
    target="${BLUE_DIRECT}"
else
    target="${GREEN_DIRECT}"
fi

echo "Triggering chaos on active app (${ACTIVE_POOL}) at ${target} ..."
curl -s -X POST "${target}/chaos/start?mode=error" || true
sleep $SLEEP_BEFORE_LOOP

# ------------------------------
# 3) Request loop
# ------------------------------
echo "Running request loop for ${TEST_DURATION}s against ${NGINX_URL}/version ..."

end=$((SECONDS + TEST_DURATION))

total=0
non200=0
count_green=0
count_blue=0

while [ $SECONDS -lt $end ]; do
    total=$((total+1))

    headers=$(mktemp)
    status=$(curl -s -D "$headers" -o /dev/null -w "%{http_code}" "${NGINX_URL}/version" || echo "000")
    pool=$(grep -i '^X-App-Pool:' "$headers" | awk '{print tolower($2)}' | tr -d '\r' || true)

    if [ "$status" != "200" ]; then
        non200=$((non200+1))
    else
        if [ "$pool" = "green" ]; then
            count_green=$((count_green+1))
        elif [ "$pool" = "blue" ]; then
            count_blue=$((count_blue+1))
        fi
    fi

    sleep 0.1
done

echo "Results: total=$total, non200=$non200, green=$count_green, blue=$count_blue"

if [ "$non200" -ne 0 ]; then
    echo "Fail: There were non-200 responses during chaos."
    exit 1
fi

# ------------------------------
# 4) Evaluate backups
# ------------------------------
if [ "$ACTIVE_POOL" = "blue" ]; then
    primary=blue; backup=green
    backup_count=$count_green
else
    primary=green; backup=blue
    backup_count=$count_blue
fi

# integer math percentage (no bc)
# multiply first to avoid decimals
backup_pct=$(( backup_count * 100 / total ))

echo "Backup responses percentage: ${backup_pct}% (need >=95%)"

# ------------------------------
# 5) Cleanup chaos
# ------------------------------
echo "Stopping chaos..."
if [ "$ACTIVE_POOL" = "blue" ]; then
    curl -s -X POST "${BLUE_DIRECT}/chaos/stop" || true
else
    curl -s -X POST "${GREEN_DIRECT}/chaos/stop" || true
fi

# PASS / FAIL
if [ "$backup_pct" -ge 95 ]; then
    echo "PASS: failover behavior OK"
    exit 0
else
    echo "FAIL: insufficient backup responses after failover"
    exit 1
fi
