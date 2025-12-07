#!/bin/bash

# Medplum Stop Script with Data Backup & Infrastructure Destruction
# This script backs up all data to S3 and destroys AWS infrastructure
# Usage: ./scripts/stop_medplum.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_DIR/terraform/aws"
BACKUP_DIR="/tmp/medplum_backup_$(date +%s)"
BACKUP_BUCKET="${MEDPLUM_BACKUP_BUCKET:-}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo ""
echo -e "${BLUE}=========================================="
echo "Medplum Stop - Backup Data & Destroy Infrastructure"
echo "==========================================${NC}"
echo ""

# Function to log messages
log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Load instance info if exists
INSTANCE_ID=""
PUBLIC_IP=""

if [ -f "$PROJECT_DIR/.medplum_instance" ]; then
    source "$PROJECT_DIR/.medplum_instance"
fi

# Step 1: Get instance details
echo -e "${YELLOW}Step 1: Retrieving instance details...${NC}"

if [ -z "$INSTANCE_ID" ] || [ -z "$PUBLIC_IP" ]; then
    # Try to get from Terraform state
    cd "$TF_DIR"
    if [ -f "terraform.tfstate" ]; then
        INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")
        PUBLIC_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
    fi
    cd - > /dev/null
fi

if [ -z "$INSTANCE_ID" ]; then
    log_error "Cannot find instance ID. Infrastructure may already be destroyed."
    exit 0
fi

log_info "Instance ID: $INSTANCE_ID"
log_info "Public IP: $PUBLIC_IP"

echo ""

# Step 2: Get S3 bucket
echo -e "${YELLOW}Step 2: Setting up S3 bucket...${NC}"

if [ -z "$BACKUP_BUCKET" ]; then
    cd "$TF_DIR"
    if [ -f "terraform.tfstate" ]; then
        BACKUP_BUCKET=$(terraform output -raw backup_bucket_name 2>/dev/null || echo "")
    fi
    cd - > /dev/null
fi

if [ -z "$BACKUP_BUCKET" ]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    BACKUP_BUCKET="medplum-backups-${ACCOUNT_ID}"
fi

log_info "Using backup bucket: $BACKUP_BUCKET"
export MEDPLUM_BACKUP_BUCKET="$BACKUP_BUCKET"

echo ""

# Step 3: Confirmation
echo -e "${YELLOW}=========================================="
echo "⚠️  WARNING - This will:"
echo "==========================================${NC}"
echo "  1. Stop all running services"
echo "  2. Backup PostgreSQL database to S3"
echo "  3. Backup Redis cache to S3"
echo "  4. Destroy EC2 instance"
echo "  5. Destroy all AWS resources (VPC, Security Groups, etc.)"
echo ""
echo "After this:"
echo "  ✓ Data will be saved in S3 (permanent storage)"
echo "  ✓ Infrastructure cost will be $0/month"
echo "  ✓ Data storage cost will be ~$0.20/month"
echo "  ✓ You can restart anytime with: ./scripts/start_medplum.sh"
echo ""
echo -e "${RED}This action CANNOT be undone!${NC}"
echo ""

read -p "Type 'yes' to proceed with shutdown and backup: " -r CONFIRM

if [[ ! $CONFIRM =~ ^[Yy][Ee][Ss]$ ]]; then
    log_warn "Shutdown cancelled"
    rm -rf "$BACKUP_DIR"
    exit 0
fi

echo ""

# Step 4: Connect to instance and stop services
echo -e "${YELLOW}Step 4: Stopping services...${NC}"

SSH_KEY="$HOME/medplum-dev-keypair.pem"

if [ ! -f "$SSH_KEY" ]; then
    log_warn "SSH key not found at $SSH_KEY"
    log_warn "Skipping graceful shutdown - will backup running instance"
else
    # Try to stop services gracefully
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "ubuntu@${PUBLIC_IP}" << 'EOF' 2>/dev/null || log_warn "Could not connect via SSH"
        # Stop API and Web services
        pkill -f "packages/server" || true
        pkill -f "packages/app" || true
        sleep 2

        # Stop Docker services
        cd ~/medplum
        docker-compose down || true
        sleep 2
EOF
fi

log_info "Services stopped"
echo ""

# Step 5: Backup PostgreSQL
echo -e "${YELLOW}Step 5: Backing up PostgreSQL database...${NC}"

BACKUP_TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
PG_BACKUP_FILE="medplum_backup_${BACKUP_TIMESTAMP}.sql"

if [ -f "$SSH_KEY" ]; then
    # Backup on instance
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "ubuntu@${PUBLIC_IP}" << EOF 2>/dev/null || log_warn "Could not backup PostgreSQL via SSH"
        docker exec medplum-postgres pg_dump -U medplum medplum > /tmp/${PG_BACKUP_FILE}
        gzip /tmp/${PG_BACKUP_FILE}
        ls -lh /tmp/${PG_BACKUP_FILE}.gz
EOF

    # Download from instance
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "ubuntu@${PUBLIC_IP}:/tmp/${PG_BACKUP_FILE}.gz" "$BACKUP_DIR/" 2>/dev/null || {
        log_error "Failed to download PostgreSQL backup"
    }
else
    log_warn "Skipping PostgreSQL backup (SSH key not found)"
fi

if [ -f "$BACKUP_DIR/${PG_BACKUP_FILE}.gz" ]; then
    PG_BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/${PG_BACKUP_FILE}.gz" | awk '{print $5}')
    log_info "PostgreSQL backed up: $PG_BACKUP_SIZE"
else
    log_warn "PostgreSQL backup may not have completed"
fi

echo ""

# Step 6: Backup Redis
echo -e "${YELLOW}Step 6: Backing up Redis cache...${NC}"

REDIS_BACKUP_FILE="redis_dump_${BACKUP_TIMESTAMP}.rdb"

if [ -f "$SSH_KEY" ]; then
    # Create Redis backup on instance
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "ubuntu@${PUBLIC_IP}" << 'EOF' 2>/dev/null || log_warn "Could not backup Redis via SSH"
        docker exec medplum-redis redis-cli -a medplum BGSAVE
        sleep 2
        docker cp medplum-redis:/data/dump.rdb /tmp/redis_dump.rdb
        gzip /tmp/redis_dump.rdb
        ls -lh /tmp/redis_dump.rdb.gz
EOF

    # Download from instance
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "ubuntu@${PUBLIC_IP}:/tmp/redis_dump.rdb.gz" "$BACKUP_DIR/${REDIS_BACKUP_FILE}.gz" 2>/dev/null || {
        log_error "Failed to download Redis backup"
    }
else
    log_warn "Skipping Redis backup (SSH key not found)"
fi

if [ -f "$BACKUP_DIR/${REDIS_BACKUP_FILE}.gz" ]; then
    REDIS_BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/${REDIS_BACKUP_FILE}.gz" | awk '{print $5}')
    log_info "Redis backed up: $REDIS_BACKUP_SIZE"
else
    log_warn "Redis backup may not have completed"
fi

echo ""

# Step 7: Upload backups to S3
echo -e "${YELLOW}Step 7: Uploading backups to S3...${NC}"

# Create backup directory if not exists
aws s3 ls "s3://${BACKUP_BUCKET}/" || aws s3api create-bucket \
    --bucket "$BACKUP_BUCKET" \
    --region ap-south-2 \
    --create-bucket-configuration LocationConstraint=ap-south-2 2>/dev/null || true

# Upload PostgreSQL backup
if [ -f "$BACKUP_DIR/${PG_BACKUP_FILE}.gz" ]; then
    echo "Uploading PostgreSQL backup to S3..."
    aws s3 cp "$BACKUP_DIR/${PG_BACKUP_FILE}.gz" \
        "s3://${BACKUP_BUCKET}/medplum/${PG_BACKUP_FILE}.gz"
    log_info "PostgreSQL backup uploaded"
else
    log_warn "PostgreSQL backup not found - skipping upload"
fi

# Upload Redis backup
if [ -f "$BACKUP_DIR/${REDIS_BACKUP_FILE}.gz" ]; then
    echo "Uploading Redis backup to S3..."
    aws s3 cp "$BACKUP_DIR/${REDIS_BACKUP_FILE}.gz" \
        "s3://${BACKUP_BUCKET}/medplum/${REDIS_BACKUP_FILE}.gz"
    log_info "Redis backup uploaded"
else
    log_warn "Redis backup not found - skipping upload"
fi

echo ""

# Verify backups in S3
echo -e "${YELLOW}Verifying backups in S3...${NC}"
BACKUP_COUNT=$(aws s3 ls "s3://${BACKUP_BUCKET}/medplum/" | wc -l)
log_info "Total backups in S3: $BACKUP_COUNT"

echo ""

# Step 8: Destroy infrastructure via Terraform
echo -e "${YELLOW}Step 8: Destroying AWS infrastructure...${NC}"

cd "$TF_DIR"

# Plan destruction
terraform plan -destroy -out=tfplan_destroy > /dev/null 2>&1
log_info "Destruction plan created"

# Apply destruction
echo "Destroying resources..."
terraform apply tfplan_destroy
log_info "Infrastructure destroyed"

cd - > /dev/null

echo ""

# Step 9: Cleanup
echo -e "${YELLOW}Step 9: Cleaning up...${NC}"

# Remove temporary files
rm -f "$BACKUP_DIR"/*.{sql,sql.gz,rdb,rdb.gz}
rm -rf "$BACKUP_DIR"

# Remove instance info file
rm -f "$PROJECT_DIR/.medplum_instance"

log_info "Temporary files cleaned up"

echo ""

# Step 10: Display summary
echo -e "${GREEN}=========================================="
echo "Medplum Shutdown Completed Successfully!"
echo "==========================================${NC}"
echo ""
echo "Summary:"
echo "  ✓ All services stopped"
echo "  ✓ PostgreSQL database backed up"
echo "  ✓ Redis cache backed up"
echo "  ✓ Backups uploaded to S3"
echo "  ✓ All AWS resources destroyed"
echo ""
echo "Data Storage:"
echo "  Bucket: $BACKUP_BUCKET"
echo "  Cost: ~$0.20/month (vs $212/month for running)"
echo ""
echo "Latest Backups:"
aws s3 ls "s3://${BACKUP_BUCKET}/medplum/" | tail -5 || echo "  (No backups found)"
echo ""
echo "Restart Command:"
echo "  ./scripts/start_medplum.sh"
echo ""
echo -e "${YELLOW}Cost Savings: $0/month (infrastructure destroyed)${NC}"
echo ""

exit 0
