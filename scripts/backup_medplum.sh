#!/bin/bash
# ============================================================================
# MEDPLUM BACKUP SCRIPT
# ============================================================================
# Backs up PostgreSQL and Redis databases to local files
# Usage: ./scripts/backup_medplum.sh
# ============================================================================

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/MEDPLUM_CONFIG.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: MEDPLUM_CONFIG.sh not found at $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Create backup directory
BACKUP_DIR="$SCRIPT_DIR/backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

echo "=========================================="
echo "Medplum Backup"
echo "=========================================="
echo "Backup Directory: $BACKUP_DIR"
echo ""

# Validate configuration
if ! validate_config; then
    echo "ERROR: Configuration validation failed"
    exit 1
fi

# Test connectivity
echo "Testing SSH connectivity..."
if ! check_connectivity; then
    echo "ERROR: Cannot connect to instance at $INSTANCE_IP"
    exit 1
fi
echo "✓ SSH connection successful"
echo ""

# Backup PostgreSQL
echo "Backing up PostgreSQL database..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PG_BACKUP_FILE="medplum_postgres_$TIMESTAMP.sql.gz"

ssh_exec "docker exec $DOCKER_POSTGRES_CONTAINER pg_dump -U $DB_USER $DB_NAME | gzip > /tmp/$PG_BACKUP_FILE"
ssh_exec "cat /tmp/$PG_BACKUP_FILE" > "$BACKUP_DIR/$PG_BACKUP_FILE"
ssh_exec "rm /tmp/$PG_BACKUP_FILE"

PG_SIZE=$(du -h "$BACKUP_DIR/$PG_BACKUP_FILE" | cut -f1)
echo "✓ PostgreSQL backup complete: $PG_BACKUP_FILE ($PG_SIZE)"

# Backup Redis
echo "Backing up Redis database..."
REDIS_BACKUP_FILE="medplum_redis_$TIMESTAMP.rdb"

ssh_exec "docker exec $DOCKER_REDIS_CONTAINER redis-cli BGSAVE"
sleep 2
ssh_exec "docker exec $DOCKER_REDIS_CONTAINER redis-cli LASTSAVE"
ssh_exec "docker exec $DOCKER_REDIS_CONTAINER cat /data/dump.rdb | gzip > /tmp/$REDIS_BACKUP_FILE"
ssh_exec "cat /tmp/$REDIS_BACKUP_FILE" > "$BACKUP_DIR/$REDIS_BACKUP_FILE"
ssh_exec "rm /tmp/$REDIS_BACKUP_FILE"

REDIS_SIZE=$(du -h "$BACKUP_DIR/$REDIS_BACKUP_FILE" | cut -f1)
echo "✓ Redis backup complete: $REDIS_BACKUP_FILE ($REDIS_SIZE)"

echo ""
echo "=========================================="
echo "Backup Summary"
echo "=========================================="
echo "Location: $BACKUP_DIR"
echo "PostgreSQL: $PG_BACKUP_FILE ($PG_SIZE)"
echo "Redis: $REDIS_BACKUP_FILE ($REDIS_SIZE)"
echo "Timestamp: $TIMESTAMP"
echo "✓ Backup completed successfully"
echo "=========================================="
