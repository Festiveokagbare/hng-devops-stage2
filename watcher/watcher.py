#!/usr/bin/env python3
import os
import re
import time
import requests
from collections import deque
from datetime import datetime, timedelta

# === Environment Variables ===
LOG_PATH = os.environ.get("NGINX_LOG", "/var/log/nginx/access.log")
SLACK_WEBHOOK = os.environ.get("SLACK_WEBHOOK_URL")
ERROR_RATE_THRESHOLD = float(os.environ.get("ERROR_RATE_THRESHOLD", "2"))  # in %
WINDOW_SIZE = int(os.environ.get("WINDOW_SIZE", "200"))
ALERT_COOLDOWN = int(os.environ.get("ALERT_COOLDOWN_SEC", "300"))  # in seconds
MAINTENANCE_MODE = os.environ.get("MAINTENANCE_MODE", "false").lower() in ("1", "true", "yes")

# === Regex to match your log lines ===
LOG_RE = re.compile(
    r'status\s(?P<status>\d{3}).*pool:(?P<pool>\S+)\s+release:(?P<release>\S+)\s+upstream_status:(?P<up_status>[^ ]+)\s+upstream_addr:(?P<up_addr>[^ ]+)'
)

# === State ===
errors_window = deque(maxlen=WINDOW_SIZE)
last_pool = None
last_failover_alert = datetime.min
last_error_alert = datetime.min

def post_slack(text, title=None):
    """Send an alert message to Slack webhook."""
    if MAINTENANCE_MODE:
        print(f"[INFO] MAINTENANCE_MODE active → suppressing alert: {text}")
        return

    if not SLACK_WEBHOOK:
        print(f"[WARN] SLACK_WEBHOOK_URL not set. Would have sent: {text}")
        return

    payload = {"text": (title + "\n" if title else "") + text}
    try:
        resp = requests.post(SLACK_WEBHOOK, json=payload, timeout=5)
        if resp.status_code >= 300:
            print(f"[ERROR] Slack send failed: {resp.status_code} {resp.text}")
    except Exception as e:
        print(f"[ERROR] Slack post exception: {e}")

def tail_f(filepath):
    """Generator that yields new lines in a log file."""
    while not os.path.exists(filepath):
        print(f"[WARN] Waiting for log file: {filepath}")
        time.sleep(2)
    with open(filepath, "r") as f:
        f.seek(0, os.SEEK_END)
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.2)
                continue
            yield line

def parse_line(line):
    """Parse a log line into a dict."""
    m = LOG_RE.search(line)
    if not m:
        return None
    data = m.groupdict()
    try:
        data["status"] = int(data["status"])
    except ValueError:
        data["status"] = 0
    return data

def check_error_rate():
    """Return (breached, rate) for rolling 5xx error rate."""
    if not errors_window:
        return False, 0.0
    total = len(errors_window)
    errors = sum(1 for s in errors_window if 500 <= s < 600)
    rate = (errors / total) * 100.0
    return rate > ERROR_RATE_THRESHOLD, rate

def now():
    return datetime.utcnow()

def main():
    global last_pool, last_failover_alert, last_error_alert
    print(f"[INFO] Watcher started — monitoring {LOG_PATH}")
    print(f"[INFO] Threshold={ERROR_RATE_THRESHOLD}%, Window={WINDOW_SIZE}, Cooldown={ALERT_COOLDOWN}s")

    for raw in tail_f(LOG_PATH):
        parsed = parse_line(raw)
        if not parsed:
            continue

        pool = parsed.get("pool")
        status = parsed.get("status", 0)
        errors_window.append(status)

        print(f"[DEBUG] pool={pool}, status={status}, up_status={parsed.get('up_status')}")

        # --- Failover Detection ---
        if last_pool is None:
            last_pool = pool

        if pool != last_pool:
            if (now() - last_failover_alert).total_seconds() > ALERT_COOLDOWN:
                msg = f"Failover detected: {last_pool} → {pool} at {now().isoformat()}\nExample log: {raw.strip()}"
                print(f"[ALERT] {msg}")
                post_slack(msg, title=":rotating_light: Failover Detected")
                last_failover_alert = now()
            last_pool = pool

        # --- Elevated 5xx Error Rate ---
        breached, rate = check_error_rate()
        if breached:
            if (now() - last_error_alert).total_seconds() > ALERT_COOLDOWN:
                msg = f"High error rate: {rate:.2f}% 5xx over last {len(errors_window)} requests\nLast log: {raw.strip()}"
                print(f"[ALERT] {msg}")
                post_slack(msg, title=":warning: Elevated 5xx Error Rate")
                last_error_alert = now()

if __name__ == "__main__":
    main()
