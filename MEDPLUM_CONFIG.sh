#!/bin/bash
# ============================================================================
# MEDPLUM CONFIGURATION - MASTER CONFIG FILE FOR ALL SCRIPTS
# ============================================================================
# This file contains all configuration values used by deployment scripts.
# UPDATE THIS FILE with your actual values before running any scripts.
# ============================================================================

# AWS CONFIGURATION
export AWS_REGION="ap-south-2"
export BACKUP_BUCKET_PREFIX="medplum-backups"

# INSTANCE CONFIGURATION
export INSTANCE_IP="40.192.106.241"
export INSTANCE_PORT_WEB=3000
export INSTANCE_PORT_API=8103
export INSTANCE_PORT_DB=5432
export INSTANCE_PORT_REDIS=6379

# SSH CONFIGURATION
export SSH_KEY="/Users/ramakrishnareddy/Downloads/medplum-dev-keypair.pem"
export SSH_USER="ubuntu"
export SSH_TIMEOUT=10

# DOCKER CONTAINER NAMES (as deployed by docker-compose)
# These MUST match the actual running container names
export DOCKER_POSTGRES_CONTAINER="medplum-postgres-1"
export DOCKER_REDIS_CONTAINER="medplum-redis-1"
export DOCKER_SERVER_CONTAINER="medplum-medplum-server-1"
export DOCKER_APP_CONTAINER="medplum-medplum-app-1"

# DATABASE CONFIGURATION (for local connections inside containers)
export DB_HOST="postgres"
export DB_PORT=5432
export DB_USER="medplum"
export DB_PASSWORD="medplum"
export DB_NAME="medplum"

# REDIS CONFIGURATION
export REDIS_HOST="redis"
export REDIS_PORT=6379
export REDIS_PASSWORD="medplum"

# MEDPLUM ENVIRONMENT VARIABLES (for docker-compose)
export MEDPLUM_BASE_URL="http://${INSTANCE_IP}:${INSTANCE_PORT_API}/"
export MEDPLUM_APP_BASE_URL="http://${INSTANCE_IP}:${INSTANCE_PORT_WEB}/"
export MEDPLUM_STORAGE_BASE_URL="http://${INSTANCE_IP}:${INSTANCE_PORT_API}/storage/"

# BACKUP CONFIGURATION
export BACKUP_RETENTION_DAYS=90
export BACKUP_COMPRESSION="gzip"

# LOGGING
export LOG_LEVEL="INFO"

# ============================================================================
# VALIDATION FUNCTION - Run this to verify configuration
# ============================================================================
validate_config() {
    echo "Validating Medplum Configuration..."

    local errors=0

    # Check SSH key exists
    if [ ! -f "$SSH_KEY" ]; then
        echo "ERROR: SSH key not found: $SSH_KEY"
        ((errors++))
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        echo "ERROR: AWS credentials not configured"
        ((errors++))
    fi

    # Validate IP format
    if ! [[ $INSTANCE_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "ERROR: Invalid INSTANCE_IP format: $INSTANCE_IP"
        ((errors++))
    fi

    if [ $errors -eq 0 ]; then
        echo "✓ Configuration validation passed"
        return 0
    else
        echo "✗ Configuration validation failed with $errors error(s)"
        return 1
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

ssh_exec() {
    # Execute command on remote instance via SSH
    local cmd="$1"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=$SSH_TIMEOUT \
        "${SSH_USER}@${INSTANCE_IP}" "$cmd"
}

check_connectivity() {
    # Check if instance is reachable via SSH
    if ssh_exec "echo 'Connected'" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

get_backup_bucket() {
    # Get or create S3 backup bucket name
    local account_id
    account_id=$(aws sts get-caller-identity --query Account --output text)
    echo "${BACKUP_BUCKET_PREFIX}-${account_id}"
}

# ============================================================================
# APP CONFIGURATION FUNCTION
# ============================================================================
# The Medplum app is a static frontend that needs environment variables
# at startup to configure the API endpoint URLs. Use this function to restart
# the app with proper configuration.

restart_app_with_config() {
    echo "Restarting Medplum app with nginx proxy configuration..."

    # Stop and remove old container
    ssh_exec "docker stop medplum-medplum-app-1 2>/dev/null || true"
    ssh_exec "docker rm -f medplum-medplum-app-1 2>/dev/null || true"

    sleep 2

    # Create nginx config with API proxy
    ssh_exec "cat > /tmp/nginx.conf << 'EOFNGINX'
server {
    listen 3000;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Proxy API requests to the server
    location /fhir/ {
        proxy_pass http://$INSTANCE_IP:$INSTANCE_PORT_API;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }

    location /assets/ {
        expires 1y;
        add_header Cache-Control \"public, no-transform\";
    }
}
EOFNGINX"

    # Start new container with nginx proxy config
    ssh_exec "docker run -d \
      --name medplum-medplum-app-1 \
      --restart always \
      -p 3000:3000 \
      -v /tmp/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
      medplum/medplum-app:latest"

    sleep 5

    echo "✓ App restarted with nginx proxy:"
    echo "  Web App: $MEDPLUM_APP_BASE_URL"
    echo "  API Proxy: /fhir/ → $MEDPLUM_BASE_URL"
}

# ============================================================================
# EXPORT FUNCTIONS FOR USE IN OTHER SCRIPTS
# ============================================================================
export -f ssh_exec
export -f check_connectivity
export -f get_backup_bucket
export -f restart_app_with_config
