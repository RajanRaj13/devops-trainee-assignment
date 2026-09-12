#!/usr/bin/env bash
# Installs db_backup.sh to /opt/scripts/ and schedules a daily cron run.
# Run this from the repo root with sudo.

set -euo pipefail

SRC="./scripts/db_backup.sh"
DEST_DIR="/opt/scripts"
DEST="${DEST_DIR}/db_backup.sh"
CRON_LINE="0 2 * * * root ${DEST} >> /var/log/db_backup_cron.log 2>&1"
CRON_FILE="/etc/cron.d/db_backup"

mkdir -p "$DEST_DIR" /var/backups/db
cp "$SRC" "$DEST"
chmod 755 "$DEST"
echo "Installed script to ${DEST}"

echo "$CRON_LINE" > "$CRON_FILE"
chmod 644 "$CRON_FILE"
echo "Cron job installed at ${CRON_FILE}:"
cat "$CRON_FILE"

echo ""
echo "Backup runs daily at 2:00 AM. To test now, run: sudo ${DEST}"
