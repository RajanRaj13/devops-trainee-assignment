# IT Infrastructure & DevOps Trainee — Practical Assignment

End-to-end setup covering Linux hardening, a Dockerized web stack behind
Nginx, automated health checks, database backups, and basic monitoring.

## Repo Layout

```
.
├── app/                        # Flask backend (Task 2)
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── nginx/
│   └── default.conf            # Reverse proxy config (Task 2)
├── docker-compose.yml          # Full stack: nginx + backend + postgres + netdata
├── .env.example                # Copy to .env before first run
├── scripts/
│   ├── infra_health_check.sh   # Task 3
│   └── db_backup.sh            # Task 4
├── setup/
│   ├── 01_create_trainee_user.sh
│   ├── 02_ssh_hardening.sh
│   ├── 03_ufw_setup.sh
│   ├── 04_install_health_check_and_cron.sh
│   └── 05_install_backup_cron.sh
└── README.md
```

---

## Task 1 — System Provisioning & Linux Administration

Provision a fresh Ubuntu 22.04/24.04 VM (VirtualBox, Proxmox, or a cloud
instance) and log in as the default user (or root) over SSH on port 22
to run the steps below.

### 1. Create the `trainee` user with sudo

```bash
sudo bash setup/01_create_trainee_user.sh
```

This creates the user, adds them to the `sudo` group, and prepares
`~/.ssh/authorized_keys`. Then, from **your local machine**, copy your
public key across (generate one with `ssh-keygen -t ed25519` if you don't
have one):

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub -p 22 trainee@<server-ip>
```

Verify you can log in with the key **before** continuing:

```bash
ssh -i ~/.ssh/id_ed25519 -p 22 trainee@<server-ip>
```

### 2. Harden SSH (disable root login, move to port 2222, key-only auth)

```bash
sudo bash setup/02_ssh_hardening.sh
```

**Do not close your current SSH session yet.** Open a *new* terminal and
confirm the new port and key-based login work:

```bash
ssh -i ~/.ssh/id_ed25519 -p 2222 trainee@<server-ip>
```

Only close the original session once that succeeds — this protects you
from getting locked out.

### 3. Configure UFW firewall

```bash
sudo bash setup/03_ufw_setup.sh
```

This denies all incoming traffic by default and explicitly allows only:
- `2222/tcp` (SSH)
- `80/tcp` (HTTP)
- `443/tcp` (HTTPS)

### Verification commands (screenshot these)

```bash
sudo ufw status verbose
sudo sshd -T | grep -E "port|permitrootlogin|passwordauthentication"
```

---

## Task 2 — Containerization & Web Services

Install Docker & Docker Compose if not already present:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker trainee
newgrp docker
```

Copy the environment template and set real credentials:

```bash
cp .env.example .env
nano .env   # set POSTGRES_PASSWORD to something real
```

Build and start the stack:

```bash
docker compose up -d --build
```

This launches:
- **`reverse_proxy`** (Nginx) — published on host port 80
- **`web_app`** (Flask/Gunicorn) — internal port 5000, not exposed to the host
- **`postgres_db`** (PostgreSQL 16) — internal only, data persisted in the
  `db_data` named volume so it survives restarts
- **`netdata`** — lightweight metrics dashboard on port 19999 (Task 4)

### Verification commands (screenshot these)

```bash
docker ps
curl http://localhost/
curl http://localhost/db-check
```

Visiting `http://<server-ip>/` in a browser should show the JSON response
from the Flask app, proxied through Nginx.

### Teardown

```bash
docker compose down          # stop and remove containers, keep the DB volume
docker compose down -v       # also delete the DB volume (destroys data)
```

---

## Task 3 — Automation & Shell Scripting

`scripts/infra_health_check.sh` checks CPU, RAM, root disk usage, whether
the Docker daemon is running, and whether the `web_app` container is up.
If disk usage exceeds 85% or the app container isn't running, it prints
`[WARNING]` and appends a timestamped entry to `/var/log/infra_health.log`.

Install it to `/opt/scripts/` and register the cron job (runs every 15
minutes):

```bash
sudo bash setup/04_install_health_check_and_cron.sh
```

### Verification commands (screenshot these)

```bash
sudo /opt/scripts/infra_health_check.sh
cat /var/log/infra_health.log
crontab -l -u root   # or: cat /etc/cron.d/infra_health_check
```

To force a `[WARNING]` for testing, stop the app container
(`docker stop web_app`) and re-run the script.

---

## Task 4 — Monitoring, Backups & Disaster Recovery

### Database backup

`scripts/db_backup.sh` runs `pg_dump` inside the `postgres_db` container,
compresses the dump to `.tar.gz`, saves it to `/var/backups/db/` as
`db_backup_YYYYMMDD.sql.tar.gz`, and prunes backups older than 7 days.

Install it and schedule a daily 2 AM run:

```bash
sudo bash setup/05_install_backup_cron.sh
```

Run it manually to test:

```bash
sudo /opt/scripts/db_backup.sh
ls -lh /var/backups/db/
```

### Restore procedure

```bash
# 1. Extract the archive
tar -xzf /var/backups/db/db_backup_YYYYMMDD.sql.tar.gz -C /var/backups/db/

# 2. Restore into the running container
cat /var/backups/db/db_backup_YYYYMMDD.sql | docker exec -i postgres_db psql -U appuser -d appdb
```

> If restoring into a brand-new/empty database, create the database first:
> `docker exec -it postgres_db createdb -U appuser appdb`

### Basic metrics/monitoring

Netdata is included in `docker-compose.yml` and starts automatically with
the stack. Access the dashboard at:

```
http://<server-ip>:19999
```

It gives real-time CPU, RAM, disk, network, and per-container Docker
metrics out of the box with zero configuration — a lightweight
alternative to running a separate Prometheus + Node Exporter stack (which
you can swap in instead if your evaluator specifically wants Prometheus;
see note below).

<details>
<summary>Optional: Prometheus + Node Exporter alternative</summary>

Add this to `docker-compose.yml` instead of/alongside netdata:

```yaml
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node_exporter
    ports:
      - "9100:9100"
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    restart: unless-stopped
```

With a minimal `prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: "node"
    static_configs:
      - targets: ["node-exporter:9100"]
```

</details>

---

## Task 5 — Git & Documentation

```bash
git init
git checkout -b feature/docker-setup
git add docker-compose.yml nginx/ app/ .env.example
git commit -m "Add Dockerized Nginx + Flask + Postgres stack"
git checkout main 2>/dev/null || git checkout -b main
git merge feature/docker-setup

git checkout -b feature/scripts
git add scripts/ setup/
git commit -m "Add health check, backup scripts, and provisioning setup"
git checkout main
git merge feature/scripts

git checkout -b feature/docs
git add README.md .gitignore
git commit -m "Add runbook documentation"
git checkout main
git merge feature/docs

git remote add origin <your-github-repo-url>
git push -u origin main
```

## Screenshots

All verification screenshots are in the [`screenshots/`](./screenshots) folder.

| # | Screenshot | Shows |
|---|---|---|
| 1 | `task1-ufw-status.png` | `sudo ufw status verbose` — firewall rules (2222/80/443 only) |
| 2 | `task1-ssh-hardening-verification.png` | SSH config check + key-based login / blocked root login |
| 3 | `task2-docker-compose-up-and-ps.png` | `docker compose up --build` + `docker ps` — all 4 containers running |
| 4 | `task2-browser-reverse-proxy-output.png` | Browser output at `http://192.168.204.137/` via Nginx reverse proxy |
| 5 | `task3-cron-job-setup.png` | Cron job registration + `systemctl status cron` |
| 6 | `task3-health-check-execution.png` | `infra_health_check.sh` running + warning triggered on disk threshold |
| 7 | `task4-db-backup-execution.png` | `db_backup.sh` running, backup archive created, restore command shown |
| 8 | `task5-git-log-branches.png` | `git log --oneline --graph --all` — branch history and merges |

---

## Quick Verification Checklist

| Check | Command |
|---|---|
| Firewall rules | `sudo ufw status verbose` |
| SSH hardened | `sudo sshd -T \| grep -E "port\|permitrootlogin\|passwordauthentication"` |
| Containers running | `docker ps` |
| Reverse proxy works | `curl http://localhost/` |
| DB persistence | `docker volume inspect devops-trainee-project_db_data` |
| Health check | `sudo /opt/scripts/infra_health_check.sh && cat /var/log/infra_health.log` |
| Cron jobs active | `cat /etc/cron.d/infra_health_check /etc/cron.d/db_backup` |
| Backup created | `ls -lh /var/backups/db/` |
| Metrics dashboard | `http://<server-ip>:19999` |
