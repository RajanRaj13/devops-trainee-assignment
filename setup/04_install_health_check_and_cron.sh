#!/usr/bin/env bash
# Installs infra_health_check.sh to /opt/scripts/, makes it executable,
# and registers a cron job to run it every 15 minutes.
# Run this from the repo root (or adjust SRC path) with sudo.

set -euo pipefail

SRC="./scripts/infra_health_check.sh"
DEST_DIR="/opt/scripts"
DEST="${DEST_DIR}/infra_health_check.sh"
LOG_FILE="/var/log/infra_health.log"
CRON_LINE="*/15 * * * * root ${DEST} >> /var/log/infra_health_cron.log 2>&1"
CRON_FILE="/etc/cron.d/infra_health_check"

mkdir -p "$DEST_DIR"
cp "$SRC" "$DEST"
chmod 755 "$DEST"
echo "Installed script to ${DEST}"

touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

echo "$CRON_LINE" > "$CRON_FILE"
chmod 644 "$CRON_FILE"
echo "Cron job installed at ${CRON_FILE}:"
cat "$CRON_FILE"

echo ""
echo "Cron will run the health check every 15 minutes as root."
echo "To test it immediately, run: sudo ${DEST}"
