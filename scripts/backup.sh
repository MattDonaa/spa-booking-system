#!/usr/bin/env bash
# ============================================================================
# Database backup — logical dump of the production database.
# ----------------------------------------------------------------------------
# Supabase takes automated daily backups (Pro plan and above) and supports
# point-in-time recovery. This script provides an additional, portable logical
# backup you can store off-platform (e.g. object storage) and is suitable for a
# scheduled job (cron / GitHub Actions).
#
# Usage:
#   SUPABASE_DB_URL="postgresql://postgres:<pw>@db.<ref>.supabase.co:5432/postgres" \
#   BACKUP_DIR=./backups ./scripts/backup.sh
#
# Requires: pg_dump (PostgreSQL client tools) matching the server major version.
# ============================================================================
set -euo pipefail

: "${SUPABASE_DB_URL:?Set SUPABASE_DB_URL to the production connection string}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

mkdir -p "$BACKUP_DIR"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
outfile="$BACKUP_DIR/spa-booking-$timestamp.dump"

echo "Creating backup: $outfile"
# Custom format (-Fc) is compressed and restorable with pg_restore.
pg_dump "$SUPABASE_DB_URL" \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file="$outfile"

echo "Backup complete ($(du -h "$outfile" | cut -f1))."

# Prune backups older than the retention window.
find "$BACKUP_DIR" -name 'spa-booking-*.dump' -type f -mtime "+$RETENTION_DAYS" -delete
echo "Pruned backups older than $RETENTION_DAYS days."
