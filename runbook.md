# Runbook — Observability & Alerts (Stage 3)


## Alerts the watcher sends


1. **Failover Detected**
   - **Meaning:** The pool seen in incoming Nginx logs changed (e.g., `blue` -> `green`). This usually means the traffic source switched — either because the primary pool stopped responding, an operator changed ACTIVE_POOL, or a load balancer/health-check caused a failover.
   - **Operator Action:**
     1. Check which pool is marked active (`docker compose exec nginx cat /etc/nginx/nginx.conf` or check environment).
     2. Inspect container health and logs of the previous primary (e.g., `docker compose logs blue_app`).
     3. If the failover was unplanned, attempt to bring the primary back: check container status, restart app container, review app logs.
     4. If failover was planned, acknowledge and optionally toggle `MAINTENANCE_MODE=true` to suppress alerts during work.


2. **Elevated 5xx Error Rate**
   - **Meaning:** The watcher detected that more than `ERROR_RATE_THRESHOLD` percent of the last `WINDOW_SIZE` requests returned 5xx responses.
   - **Operator Action:**
     1. Inspect recent Nginx and app log