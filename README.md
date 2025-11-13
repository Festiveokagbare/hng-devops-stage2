

HNG DevOps Stage 3: Blue/Green Failover Infrastructure
<div align="center"> HNG DevOps Stage 3 Blue/Green Deployment · Container Failover · Health Checks · Slack Alerts </div>


🚀 Objective
Configure a Blue/Green deployment using Docker Compose and NGINX such that:
1. Blue and Green app containers are both running
2. NGINX routes traffic to the active pool
3. On failure, traffic automatically moves to the backup
4. /version exposes metadata via HTTP headers
5. /healthz is used for health checks
6. Watcher monitors logs and sends Slack alerts

This repository implements all required capabilities.

🏗️ Architecture
                    ┌────────────────────────┐
                    │        Client           │
                    │ curl / browser / grader │
                    └────────────┬────────────┘
                                 │ :8080
                          ┌──────▼───────┐
                          │   NGINX      │
                          │ Reverse Proxy│
                          └─────┬────────┘
                ┌───────────────┼────────────────┐
                │               │                │
      Active →  │      Blue App │   Green App    │  ← Backup
                │    :8081      │    :8082       │
                └───────────────┴────────────────┘


Failover occurs if the active app:
1. Crashes
2. Times out
3. Returns 5xx

Watcher service monitors /var/log/nginx/access.log and automatically posts alerts to Slack when:
1. Failover occurs
2. Elevated 5xx error rate is detected

⚙️ Tech Stack
1. Docker & Docker Compose
NGINX reverse proxy
2. Health checks + failover logic
3. Slack alerts via watcher service
4. Google Cloud Compute Engine (VM deployment)
5. Environment-driven configuration

🚢 Setup Instructions

Clone repo
git clone https://github.com/Festiveokagbare/hng-devops-stage2.git
cd hng-devops-stage2

Make scripts executable
chmod +x nginx/start.sh
chmod +x test/failover-test.sh
chmod +x deploy.sh


Setup environment variables
cp .env.example .env
# Edit .env to configure Slack webhook URL and ports if needed

▶️ Run Locally
docker compose up -d

View logs:
docker compose logs -f

Stop:
docker compose down -v

🌐 Endpoints
Endpoint	Description
/version	Returns app pool & release ID
/healthz	Up/down health
/	Demo root route

Verify Blue is active:
curl -i http://localhost:8080/version


Example output:
X-App-Pool: blue
X-Release-Id: blue-v1

🔁 Failover Demonstration
Stop Blue
docker stop hng-devops-stage2-app_blue-1


Request again
curl -i http://localhost:8080/version


Expected:
X-App-Pool: green
X-Release-Id: green-v1


✅ Traffic automatically moved to Green.
🔄 Switching Traffic Manually

Edit .env:
ACTIVE_POOL=green


Recreate proxy:
docker compose down
docker compose up -d

🧰 Health Check Test
curl -i http://localhost:8080/healthz

🧬 Failover CI (GitHub Actions)

💻 Watcher / Slack Alerts
Watcher service (alert_watcher) runs alongside NGINX and app containers to monitor logs:
1. Watches /var/log/nginx/access.log
2. Detects failover between Blue/Green pools
3. Detects elevated 5xx error rates
4. Sends notifications to Slack (configured via .env: SLACK_WEBHOOK_URL)

Test watcher manually:
docker exec -it hng-devops-stage2-alert_watcher-1 python3 -c \
'import os, requests; url=os.getenv("SLACK_WEBHOOK_URL"); \
requests.post(url, json={"text": ":rotating_light: Test alert from watcher!"})'

☁️ Cloud Deployment
1. Infrastructure deployed on Google Cloud Compute Engine:
2. Ubuntu VM with Docker & Docker Compose
3. Blue and Green app containers running simultaneously
4. NGINX reverse proxy managing failover
5. Watcher monitoring logs & sending Slack alerts

Deployment script: deploy.sh
./deploy.sh


Allow firewall for ports 8080, 8081, 8082:

gcloud compute firewall-rules create allow-http-8080 --allow tcp:8080,8081,8082


Access via:
http://<EXTERNAL_IP>:8080

👀 Visual Deployment Diagram
graph TD
    A[Deploy New Green Version] --> C{Healthy?}
    C -->|Yes| D[NGINX switches to Green]
    C -->|No| E[Rollback to Blue]
    D --> F[Old Blue pool destroyed]

🔍 Example curl Suite

View version repeatedly:
for i in {1..6}; do curl -s -I localhost:8080/version | grep X-App-Pool; sleep 1; done


Verify Release IDs:
curl -I localhost:8080/version | grep X-Release-Id


Check root:
curl localhost:8080

🚑 Troubleshooting
NGINX restarting? Check logs:
docker compose logs nginx


Port conflicts? Stop conflicting process:
lsof -i :8080

📁 Project Structure
.
├── docker-compose.yml
├── nginx/
│   ├── nginx.conf.template
│   └── start.sh
├── test/
│   └── failover-test.sh
├── watcher/
│   └── watcher.py
|   |__ Dockerfile
|   |__ requirement.txt
├── deploy.sh
├── .env.example
└── README.md

📣 Contribution Notes

Pull requests welcome.

✅ Completion Criteria (Met)
1. Both pools run simultaneously
2. /version exposes metadata via headers
3. Failover within same request
4. /healthz health endpoint
4. Failover CI test
5. Slack alerts via watcher
6. Docker Compose orchestrated

⭐ Final Thoughts
1. Zero downtime deployment strategy
2. Instant failover capabilities
3. Production-grade proxy and alert configuration

🙌 Author
Festus Okagbare
DevOps / Cloud Engineer
