HNG DevOps Stage 2: Blue/Green Failover Infrastructure


<div align="center">
HNG DevOps Stage 2
Blue/Green Deployment · Container Failover · Health Checks

</div>


🚀 Objective

 Configure a Blue/Green deployment using Docker Compose and NGINX such that:
1. Blue and Green app containers are both running
2. NGINX routes traffic to the active pool
3. On failure, traffic automatically moves to the backup
4. /version exposes metadata via HTTP headers
5. /healthz is used for health checks

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
1. crashes
2. times out
3. returns 5xx

⚙️ Tech Stack
1. Docker & Docker Compose
2. NGINX reverse proxy
3. Health checks + failover logic
4. GitHub Actions CI pipeline
5. Environment-driven configuration


🚢 Setup Instructions
1. Clone repo
git clone https://github.com/Festiveokagbare/hng-devops-stage2.git
cd hng-devops-stage2

2. Make scripts executable
chmod +x nginx/start.sh
chmod +x test/failover-test.sh

📦 Environment Variables
Provided in .env:

BLUE_IMAGE=yimikaade/wonderful:devops-stage-two
GREEN_IMAGE=yimikaade/wonderful:devops-stage-two
ACTIVE_POOL=blue
RELEASE_ID_BLUE=blue-v1
RELEASE_ID_GREEN=green-v1
PORT=3000
NGINX_HOST_PORT=8080
BLUE_HOST_PORT=8081
GREEN_HOST_PORT=8082


Copy example:
    cp .env.example .env

▶️ Run Locally
docker compose up -d


View logs:
    docker compose logs -f


Stop:
    docker compose down -v

🌐 Endpoints
Endpoint	Description
    1. /version	Returns app pool & release ID
    2. /healthz	Up/down health
    3. /	Demo root route

🧪 Verify Blue is Active
curl -i http://localhost:8080/version


Example output:
    X-App-Pool: blue
    X-Release-Id: blue-v1

🔁 Failover Demonstration
1. Stop Blue
    docker stop hng-devops-stage2-app_blue-1

2. Request again
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
    This repository contains:
        1. .github/workflows/stage2.yml


⚙️ GitHub Actions CI Integration
This repository includes a workflow:
    1. Boots entire infrastructure
    2. Waits for /version 200 OK
    3. Executes failover test script
    4. Tears everything down afterward

CI file: .github/workflows/ci.yml

CI Badges
    Update repo name first, then paste:
    ![CI](https://github.com/<user>/<repo>/actions/workflows/ci.yml/badge.svg)


Secrets required:
Name	                Example value
BLUE_IMAGE	            yimikaade/wonderful:devops-stage-two
GREEN_IMAGE	            same image OK


Add in:
Settings → Secrets → Actions


👀 Visual Deployment Diagram
graph TD
    A[Deploy New Green Version] --> C{Healthy?}
    C -->|Yes| D[NGINX switches to Green]
    C -->|No| E[Rollback to Blue]
    D --> F[Old Blue pool destroyed]


🧾 Sample JSON Response
{
  "status": "OK",
  "message": "Application version in header"
}



🔍 Example curl Suite
View version repeatedly
for i in {1..6}; do curl -s -I localhost:8080/version | grep X-App-Pool; sleep 1; done


Verify Release IDs
curl -I localhost:8080/version | grep X-Release-Id


Check root
curl localhost:8080

🚑 Troubleshooting
NGINX restarting?


Check config:
    1. docker compose logs nginx

Port already in use?

Stop conflicting process:
lsof -i :8080


📁 Project Structure
.
├── docker-compose.yml
├── nginx/
│   ├── nginx.conf.template
│   └── start.sh
├── test/
│   └── failover-test.sh
├── .github/workflows/stage2.yml
├── .env.example
└── README.md


📣 Contribution Notes
    Pull requests welcome.


✅ Completion Criteria (Met)
1. Both pools run simultaneously
2. /version exposes metadata via headers
3. Failover within same request
4. /healthz health endpoint
5. Failover CI test
6. Docker Compose orchestrated


⭐ Final Thoughts

This implementation ensures:
1. Zero downtime deployment strategy
2. Instant failover capabilities
3. Production-grade proxy configuration


🙌 Author

Festus Okagbare
DevOps/Cloud Engineer