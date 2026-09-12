#!/usr/bin/env bash
#
# infra_health_check.sh
# Checks CPU, RAM, disk, Docker status, and the web app container.
# Logs a [WARNING] to /var/log/infra_health.log if disk > 85% or the
# app container is not running.
#
# Intended location: /opt/scripts/infra_health_check.sh
# Run every 15 minutes via cron (see setup/03_cron_setup.sh)

set -uo pipefail

LOG_FILE="/var/log/infra_health.log"
DISK_THRESHOLD=85
APP_CONTAINER_NAME="web_app"   # matches container_name in docker-compose.yml
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# Ensure log file exists and is writable (falls back gracefully if not root)
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="./infra_health.log"
fi

log_warning() {
    local message="$1"
    echo "[WARNING] $message"
    echo "${TIMESTAMP} [WARNING] ${message}" >> "$LOG_FILE"
}

log_info() {
    local message="$1"
    echo "[INFO] $message"
}

echo "=================================================="
echo " Infra Health Check - ${TIMESTAMP}"
echo "=================================================="

# --- CPU Usage ---
# Uses /proc/stat for a portable snapshot-based CPU usage calculation
if command -v mpstat >/dev/null 2>&1; then
    CPU_USAGE=$(mpstat 1 1 | awk '/Average/ {print 100 - $NF}')
else
    CPU_IDLE_1=($(grep '^cpu ' /proc/stat))
    sleep 1
    CPU_IDLE_2=($(grep '^cpu ' /proc/stat))
    PREV_IDLE=${CPU_IDLE_1[4]}
    IDLE=${CPU_IDLE_2[4]}
    PREV_TOTAL=0
    TOTAL=0
    for i in 1 2 3 4 5 6 7; do
        PREV_TOTAL=$((PREV_TOTAL + ${CPU_IDLE_1[$i]:-0}))
        TOTAL=$((TOTAL + ${CPU_IDLE_2[$i]:-0}))
    done
    DIFF_IDLE=$((IDLE - PREV_IDLE))
    DIFF_TOTAL=$((TOTAL - PREV_TOTAL))
    if [ "$DIFF_TOTAL" -gt 0 ]; then
        CPU_USAGE=$(awk -v idle="$DIFF_IDLE" -v total="$DIFF_TOTAL" 'BEGIN {printf "%.1f", (1 - idle/total) * 100}')
    else
        CPU_USAGE="N/A"
    fi
fi
log_info "CPU usage: ${CPU_USAGE}%"

# --- RAM Usage ---
RAM_LINE=$(free -m | awk '/^Mem:/ {printf "%.1f", ($3/$2) * 100}')
RAM_USED_MB=$(free -m | awk '/^Mem:/ {print $3}')
RAM_TOTAL_MB=$(free -m | awk '/^Mem:/ {print $2}')
log_info "RAM usage: ${RAM_LINE}% (${RAM_USED_MB}MB / ${RAM_TOTAL_MB}MB)"

# --- Root Disk Usage ---
DISK_USAGE=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
log_info "Root disk usage: ${DISK_USAGE}%"

if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ] 2>/dev/null; then
    log_warning "Root disk usage is ${DISK_USAGE}%, exceeding threshold of ${DISK_THRESHOLD}%."
fi

# --- Docker Daemon Status ---
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    log_info "Docker daemon is running."

    # --- Application Container Status ---
    CONTAINER_STATE=$(docker inspect -f '{{.State.Status}}' "$APP_CONTAINER_NAME" 2>/dev/null)

    if [ -z "$CONTAINER_STATE" ]; then
        log_warning "Application container '${APP_CONTAINER_NAME}' not found."
    elif [ "$CONTAINER_STATE" != "running" ]; then
        log_warning "Application container '${APP_CONTAINER_NAME}' is in state '${CONTAINER_STATE}' (expected: running)."
    else
        log_info "Application container '${APP_CONTAINER_NAME}' is running."
    fi
else
    log_warning "Docker daemon is not running or Docker is not installed."
fi

echo "=================================================="
echo " Health check complete. Warnings (if any) logged to ${LOG_FILE}"
echo "=================================================="

exit 0
