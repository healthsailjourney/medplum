#!/bin/bash
# ============================================================================
# MEDPLUM RESTORE SCRIPT
# ============================================================================
# Restores PostgreSQL and Redis databases from backup files
# Usage: ./scripts/restore_medplum.sh [timestamp]
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

echo "=========================================="
echo "Medplum Restore"
echo "=========================================="
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

# List available backups
echo "Available backups:"
BACKUP_DIR="$SCRIPT_DIR/backups"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: No backup directory found at $BACKUP_DIR"
    exit 1
fi

# Find latest backups
LATEST_BACKUP=$(find "$BACKUP_DIR" -name "medplum_postgres_*.sql.gz" | sort -r | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "ERROR: No backups found in $BACKUP_DIR"
    exit 1
fi

LATEST_TIMESTAMP=$(basename "$LATEST_BACKUP" | sed 's/medplum_postgres_//g' | sed 's/.sql.gz//g')
BACKUP_DATE_DIR="$BACKUP_DIR/$(echo $LATEST_TIMESTAMP | cut -d_ -f1)"

echo "Latest backup timestamp: $LATEST_TIMESTAMP"
echo "Backup directory: $BACKUP_DATE_DIR"
echo ""

# Get backup files
PG_BACKUP_FILE="medplum_postgres_$LATEST_TIMESTAMP.sql.gz"
REDIS_BACKUP_FILE="medplum_redis_$LATEST_TIMESTAMP.rdb.gz"

if [ ! -f "$BACKUP_DATE_DIR/$PG_BACKUP_FILE" ]; then
    echo "ERROR: PostgreSQL backup not found: $BACKUP_DATE_DIR/$PG_BACKUP_FILE"
    exit 1
fi

if [ ! -f "$BACKUP_DATE_DIR/$REDIS_BACKUP_FILE" ]; then
    echo "WARNING: Redis backup not found: $BACKUP_DATE_DIR/$REDIS_BACKUP_FILE"
fi

echo "Preparing to restore from:"
echo "  PostgreSQL: $PG_BACKUP_FILE"
[ -f "$BACKUP_DATE_DIR/$REDIS_BACKUP_FILE" ] && echo "  Redis: $REDIS_BACKUP_FILE"
echo ""

read -p "Continue with restore? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
fi

# Stop API server to prevent conflicts
echo "Stopping API server..."
ssh_exec "docker stop $DOCKER_SERVER_CONTAINER 2>/dev/null || true"
sleep 2

# Restore PostgreSQL
echo "Restoring PostgreSQL database..."
cat "$BACKUP_DATE_DIR/$PG_BACKUP_FILE" | \
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "${SSH_USER}@${INSTANCE_IP}" \
    "gunzip | docker exec -i $DOCKER_POSTGRES_CONTAINER psql -U $DB_USER $DB_NAME"

echo "✓ PostgreSQL restore complete"

# Restore Redis (if backup exists)
if [ -f "$BACKUP_DATE_DIR/$REDIS_BACKUP_FILE" ]; then
    echo "Restoring Redis database..."

    # Stop Redis temporarily
    ssh_exec "docker exec $DOCKER_REDIS_CONTAINER redis-cli SHUTDOWN"
    sleep 2

    # Copy backup file
    ssh_exec "mkdir -p /tmp/redis_restore"
    cat "$BACKUP_DATE_DIR/$REDIS_BACKUP_FILE" | \
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "${SSH_USER}@${INSTANCE_IP}" \
        "gunzip > /tmp/redis_restore/dump.rdb"

    # Copy to Redis data directory
    ssh_exec "docker exec -u root $DOCKER_REDIS_CONTAINER cp /tmp/redis_restore/dump.rdb /data/dump.rdb"
    ssh_exec "docker exec -u root $DOCKER_REDIS_CONTAINER chown redis:redis /data/dump.rdb"

    # Restart Redis
    ssh_exec "docker restart $DOCKER_REDIS_CONTAINER"
    sleep 2

    echo "✓ Redis restore complete"
fi

# Restart API server
echo "Restarting API server..."
ssh_exec "docker start $DOCKER_SERVER_CONTAINER"
sleep 5

# Verify restore
echo ""
echo "Verifying restore..."
HEALTH=$(ssh_exec "curl -s http://localhost:8103/healthcheck" | grep -o '"ok":true' || echo "")

if [ -n "$HEALTH" ]; then
    echo "✓ API server is healthy"
else
    echo "⚠ API server health check failed - may need additional time to start"
fi

echo ""
echo "=========================================="
echo "Restore Summary"
echo "=========================================="
echo "Restored from timestamp: $LATEST_TIMESTAMP"
echo "PostgreSQL: Restored"
[ -f "$BACKUP_DATE_DIR/$REDIS_BACKUP_FILE" ] && echo "Redis: Restored"
echo "✓ Restore completed"
echo "=========================================="
