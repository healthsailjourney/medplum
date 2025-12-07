#!/bin/bash
# ============================================================================
# MEDPLUM LIST BACKUPS SCRIPT
# ============================================================================
# Lists all available backups with details
# Usage: ./scripts/list_backups.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups"

echo "=========================================="
echo "Medplum Backups"
echo "=========================================="
echo ""

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup directory found at $BACKUP_DIR"
    exit 0
fi

# Find all PostgreSQL backups
echo "PostgreSQL Backups:"
echo "----------------------------------------"

PG_COUNT=0
find "$BACKUP_DIR" -name "medplum_postgres_*.sql.gz" -type f | sort -r | while read BACKUP; do
    FILENAME=$(basename "$BACKUP")
    SIZE=$(du -h "$BACKUP" | cut -f1)
    DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$BACKUP" 2>/dev/null || stat -c %y "$BACKUP" 2>/dev/null | cut -d. -f1)
    echo "  $FILENAME"
    echo "    Size: $SIZE"
    echo "    Date: $DATE"
    echo ""
    ((PG_COUNT++))
done

PG_TOTAL=$(find "$BACKUP_DIR" -name "medplum_postgres_*.sql.gz" -type f | wc -l)
echo "Total PostgreSQL backups: $PG_TOTAL"
echo ""

# Find all Redis backups
echo "Redis Backups:"
echo "----------------------------------------"

REDIS_COUNT=0
find "$BACKUP_DIR" -name "medplum_redis_*.rdb.gz" -type f | sort -r | while read BACKUP; do
    FILENAME=$(basename "$BACKUP")
    SIZE=$(du -h "$BACKUP" | cut -f1)
    DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$BACKUP" 2>/dev/null || stat -c %y "$BACKUP" 2>/dev/null | cut -d. -f1)
    echo "  $FILENAME"
    echo "    Size: $SIZE"
    echo "    Date: $DATE"
    echo ""
    ((REDIS_COUNT++))
done

REDIS_TOTAL=$(find "$BACKUP_DIR" -name "medplum_redis_*.rdb.gz" -type f | wc -l)
echo "Total Redis backups: $REDIS_TOTAL"
echo ""

# Storage usage
echo "Storage Usage:"
echo "----------------------------------------"
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "Total backup storage: $TOTAL_SIZE"

# Estimate retention cost
# AWS S3 standard: $0.023 per GB/month
TOTAL_SIZE_GB=$(du -s "$BACKUP_DIR" | awk '{print $1/1024/1024}')
MONTHLY_COST=$(echo "$TOTAL_SIZE_GB * 0.023" | bc -l | xargs printf "%.2f")
echo "Estimated S3 storage cost: ~\$$MONTHLY_COST/month"
echo ""

echo "=========================================="
