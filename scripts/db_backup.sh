#!/usr/bin/env bash
#
# db_backup.sh
# Dumps the PostgreSQL database running in the "postgres_db" container,
# compresses it, and stores it in /var/backups/db/ with a timestamp.
#
# Intended location: /opt/scripts/db_backup.sh
# Retention: keeps the last 7 daily backups automatically.
#
# Restore command is printed at the end of a successful run and is also
# documented in the README.

set -euo pipefail

# ---- Config ----
DB_CONTAINER="postgres_db"
DB_NAME="${POSTGRES_DB:-appdb}"
DB_USER="${POSTGRES_USER:-appuser}"
BACKUP_DIR="/var/backups/db"
RETENTION_DAYS=7
DATE_STAMP="$(date '+%Y%m%d')"
DUMP_FILE="db_backup_${DATE_STAMP}.sql"
ARCHIVE_FILE="${DUMP_FILE}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup of database '${DB_NAME}'..."

# Dump the database from inside the running container, write to a temp file
if ! docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" > "${BACKUP_DIR}/${DUMP_FILE}"; then
    echo "[ERROR] pg_dump failed. Aborting backup." >&2
    rm -f "${BACKUP_DIR}/${DUMP_FILE}"
    exit 1
fi

# Compress the dump into a .tar.gz archive
tar -czf "${BACKUP_DIR}/${ARCHIVE_FILE}" -C "$BACKUP_DIR" "$DUMP_FILE"
rm -f "${BACKUP_DIR}/${DUMP_FILE}"

echo "[OK] Backup created: ${BACKUP_DIR}/${ARCHIVE_FILE}"

# ---- Retention: delete backups older than RETENTION_DAYS ----
find "$BACKUP_DIR" -name "db_backup_*.sql.tar.gz" -mtime "+${RETENTION_DAYS}" -exec rm -f {} \;
echo "[INFO] Old backups older than ${RETENTION_DAYS} days removed (if any)."

echo ""
echo "To restore this backup:"
echo "  tar -xzf ${BACKUP_DIR}/${ARCHIVE_FILE} -C ${BACKUP_DIR}"
echo "  cat ${BACKUP_DIR}/${DUMP_FILE} | docker exec -i ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME}"

exit 0
