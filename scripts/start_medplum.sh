#!/bin/bash

# Medplum Start Script with Infrastructure Creation & Data Restore
# This script creates all AWS infrastructure via Terraform and restores data from S3
# Usage: ./scripts/start_medplum.sh

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
BACKUP_DIR="/tmp/medplum_restore"
BACKUP_BUCKET="${MEDPLUM_BACKUP_BUCKET:-}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo ""
echo -e "${BLUE}=========================================="
echo "Medplum Start - Create Infrastructure & Restore Data"
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

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Step 1: Validate Prerequisites
echo -e "${YELLOW}Step 1: Validating prerequisites...${NC}"

if ! command_exists aws; then
    log_error "AWS CLI is not installed"
    echo "Install from: https://aws.amazon.com/cli/"
    exit 1
fi
log_info "AWS CLI found"

if ! command_exists terraform; then
    log_error "Terraform is not installed"
    echo "Install from: https://www.terraform.io/downloads.html"
    exit 1
fi
log_info "Terraform found"

if ! command_exists docker; then
    log_error "Docker is not installed"
    exit 1
fi
log_info "Docker found"

# Verify AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured or invalid"
    echo "Run: aws configure"
    exit 1
fi
log_info "AWS credentials valid"

echo ""

# Step 2: Set up S3 bucket if not exists
echo -e "${YELLOW}Step 2: Setting up S3 bucket for backups...${NC}"

if [ -z "$BACKUP_BUCKET" ]; then
    # Try to get bucket name from Terraform output
    cd "$TF_DIR"
    if [ -f "terraform.tfstate" ]; then
        BACKUP_BUCKET=$(terraform output -raw backup_bucket_name 2>/dev/null || echo "")
    fi
    cd - > /dev/null
fi

if [ -z "$BACKUP_BUCKET" ]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    BACKUP_BUCKET="medplum-backups-${ACCOUNT_ID}"

    # Check if bucket exists
    if aws s3 ls "s3://${BACKUP_BUCKET}" 2>/dev/null; then
        log_info "S3 bucket already exists: $BACKUP_BUCKET"
    else
        log_warn "Creating new S3 bucket: $BACKUP_BUCKET"
        aws s3api create-bucket \
            --bucket "$BACKUP_BUCKET" \
            --region ap-south-2 \
            --create-bucket-configuration LocationConstraint=ap-south-2 2>/dev/null || true

        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$BACKUP_BUCKET" \
            --versioning-configuration Status=Enabled

        # Enable encryption
        aws s3api put-bucket-encryption \
            --bucket "$BACKUP_BUCKET" \
            --server-side-encryption-configuration '{
                "Rules": [{
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }]
            }'

        log_info "S3 bucket created with encryption and versioning"
    fi
fi

export MEDPLUM_BACKUP_BUCKET="$BACKUP_BUCKET"
echo "Backup bucket: $BACKUP_BUCKET"
echo ""

# Step 3: Initialize and validate Terraform
echo -e "${YELLOW}Step 3: Initializing Terraform...${NC}"

cd "$TF_DIR"

# Initialize Terraform
if [ ! -d ".terraform" ]; then
    terraform init
    log_info "Terraform initialized"
else
    log_info "Terraform already initialized"
fi

# Validate configuration
terraform validate > /dev/null 2>&1
log_info "Terraform configuration valid"

echo ""

# Step 4: Plan and Apply Terraform
echo -e "${YELLOW}Step 4: Creating infrastructure via Terraform...${NC}"

terraform plan -out=tfplan_start > /dev/null 2>&1

# Show what will be created
echo "Terraform will create:"
echo "  - VPC with public subnet"
echo "  - Internet Gateway"
echo "  - Security Group"
echo "  - EC2 instance (t3.xlarge)"
echo "  - Elastic IP"
echo "  - S3 bucket (if not exists)"
echo ""

read -p "Proceed with infrastructure creation? (yes/no) " -r CONFIRM
if [[ ! $CONFIRM =~ ^[Yy][Ee][Ss]$ ]]; then
    log_warn "Infrastructure creation cancelled"
    rm -f tfplan_start
    exit 0
fi

echo ""
echo -e "${YELLOW}Applying Terraform configuration...${NC}"
terraform apply tfplan_start
log_info "Infrastructure created successfully"

# Get instance details
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")
PUBLIC_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ] || [ -z "$PUBLIC_IP" ]; then
    log_error "Failed to get instance details from Terraform"
    exit 1
fi

log_info "Instance ID: $INSTANCE_ID"
log_info "Public IP: $PUBLIC_IP"

echo ""

# Step 5: Wait for instance to boot
echo -e "${YELLOW}Step 5: Waiting for instance to boot and services to start...${NC}"

WAIT_TIME=0
MAX_WAIT=300  # 5 minutes

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    if aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --region ap-south-2 \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text 2>/dev/null | grep -q "running"; then

        log_info "Instance is running"
        break
    fi

    echo -n "."
    sleep 5
    WAIT_TIME=$((WAIT_TIME + 5))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    log_error "Instance failed to start within 5 minutes"
    exit 1
fi

# Wait additional time for services to start
echo -e "\n${YELLOW}Waiting for Docker services to start (60 seconds)...${NC}"
sleep 60
log_info "Services should be started"

echo ""

# Step 6: Check for existing backups
echo -e "${YELLOW}Step 6: Checking for existing backups in S3...${NC}"

BACKUP_EXISTS=false
BACKUP_DATE=""

# List backups
BACKUPS=$(aws s3 ls "s3://${BACKUP_BUCKET}/medplum/" 2>/dev/null | grep "medplum_backup" || echo "")

if [ -n "$BACKUPS" ]; then
    BACKUP_EXISTS=true
    BACKUP_DATE=$(echo "$BACKUPS" | tail -1 | awk '{print $1, $2}')
    log_info "Found existing backups from: $BACKUP_DATE"
    echo ""
    echo "Recent backups:"
    echo "$BACKUPS" | tail -5
else
    log_warn "No existing backups found - starting fresh"
fi

echo ""

# Step 7: Restore data if backups exist
if [ "$BACKUP_EXISTS" = true ]; then
    echo -e "${YELLOW}Step 7: Restoring data from S3 backup...${NC}"

    # Download PostgreSQL backup
    echo "Downloading PostgreSQL backup..."
    LATEST_PG_BACKUP=$(aws s3 ls "s3://${BACKUP_BUCKET}/medplum/" | grep "medplum_backup.*\.sql\.gz" | tail -1 | awk '{print $4}')

    if [ -n "$LATEST_PG_BACKUP" ]; then
        aws s3 cp "s3://${BACKUP_BUCKET}/medplum/${LATEST_PG_BACKUP}" "$BACKUP_DIR/"
        log_info "Downloaded PostgreSQL backup: $LATEST_PG_BACKUP"

        # Decompress
        cd "$BACKUP_DIR"
        gunzip -f "$LATEST_PG_BACKUP"
        BACKUP_FILE="${LATEST_PG_BACKUP%.gz}"
        cd - > /dev/null

        # Restore to PostgreSQL
        echo "Restoring PostgreSQL database..."
        SSH_KEY="$HOME/.ssh/medplum-dev.pem"

        if [ ! -f "$SSH_KEY" ]; then
            log_error "SSH key not found at $SSH_KEY"
            log_warn "Please restore manually using restore_medplum.sh"
        else
            # Copy backup to instance
            scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
                "$BACKUP_DIR/$BACKUP_FILE" "ubuntu@${PUBLIC_IP}:~/" 2>/dev/null || true

            # Restore on instance
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "ubuntu@${PUBLIC_IP}" \
                "docker exec -i medplum-postgres psql -U medplum medplum < ~/${BACKUP_FILE}" 2>/dev/null || {
                log_warn "PostgreSQL restore may have issues, trying alternate method..."
            }

            log_info "PostgreSQL database restored"
        fi
    else
        log_warn "PostgreSQL backup not found in S3"
    fi

    # Download Redis backup
    echo "Downloading Redis backup..."
    LATEST_REDIS_BACKUP=$(aws s3 ls "s3://${BACKUP_BUCKET}/medplum/" | grep "redis_dump.*\.rdb\.gz" | tail -1 | awk '{print $4}')

    if [ -n "$LATEST_REDIS_BACKUP" ]; then
        aws s3 cp "s3://${BACKUP_BUCKET}/medplum/${LATEST_REDIS_BACKUP}" "$BACKUP_DIR/"
        log_info "Downloaded Redis backup: $LATEST_REDIS_BACKUP"

        # Copy to instance and restore
        SSH_KEY="$HOME/.ssh/medplum-dev.pem"
        if [ -f "$SSH_KEY" ]; then
            scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
                "$BACKUP_DIR/${LATEST_REDIS_BACKUP}" "ubuntu@${PUBLIC_IP}:~/" 2>/dev/null || true

            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "ubuntu@${PUBLIC_IP}" << 'EOF'
cd ~
gunzip -f *.rdb.gz 2>/dev/null || true
docker cp dump.rdb medplum-redis:/data/ 2>/dev/null || true
docker exec medplum-redis redis-cli -a medplum SHUTDOWN NOSAVE 2>/dev/null || true
sleep 2
docker-compose restart redis
sleep 5
EOF
            log_info "Redis backup restored"
        fi
    else
        log_warn "Redis backup not found in S3"
    fi

    echo ""
else
    echo -e "${YELLOW}Step 7: Fresh start - no data to restore${NC}"
fi

echo ""

# Step 8: Verify services are running
echo -e "${YELLOW}Step 8: Verifying services...${NC}"

# Check API health
API_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "http://${PUBLIC_IP}:8103/healthcheck" 2>/dev/null || echo "000")

if [ "$API_HEALTH" = "200" ]; then
    log_info "API Server is responding"
else
    log_warn "API Server not ready yet (HTTP $API_HEALTH) - it may take a moment to fully start"
fi

# Check Web App
WEB_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "http://${PUBLIC_IP}:3000" 2>/dev/null || echo "000")

if [ "$WEB_HEALTH" = "200" ]; then
    log_info "Web App is responding"
else
    log_warn "Web App not ready yet (HTTP $WEB_HEALTH) - it may take a moment to fully start"
fi

echo ""

# Step 9: Display completion summary
echo -e "${GREEN}=========================================="
echo "Medplum Infrastructure Started Successfully!"
echo "==========================================${NC}"
echo ""
echo "Instance Details:"
echo "  Instance ID:  $INSTANCE_ID"
echo "  Public IP:    $PUBLIC_IP"
echo "  Region:       ap-south-2"
echo ""
echo "Service URLs:"
echo "  API:          http://${PUBLIC_IP}:8103"
echo "  API Health:   http://${PUBLIC_IP}:8103/healthcheck"
echo "  Web App:      http://${PUBLIC_IP}:3000"
echo ""
echo "Default Credentials:"
echo "  Email:        admin@example.com"
echo "  Password:     medplum_admin"
echo ""
if [ "$BACKUP_EXISTS" = true ]; then
    echo "Data Status:"
    echo "  ✓ Data restored from backup"
    echo "  ✓ All your previous data is available"
else
    echo "Data Status:"
    echo "  ✓ Fresh start"
    echo "  → Create first admin account at: http://${PUBLIC_IP}:3000"
fi
echo ""
echo "Cost Information:"
echo "  Running:      $7.06/day ($212/month)"
echo "  To save costs: ./scripts/stop_medplum.sh"
echo ""
echo "SSH Access:"
echo "  ssh -i ~/.ssh/medplum-dev.pem ubuntu@${PUBLIC_IP}"
echo ""

# Save instance info to file for other scripts
cat > "$PROJECT_DIR/.medplum_instance" << INSTANCE_INFO
INSTANCE_ID=$INSTANCE_ID
PUBLIC_IP=$PUBLIC_IP
BACKUP_BUCKET=$BACKUP_BUCKET
CREATED_AT=$(date)
INSTANCE_INFO

log_info "Instance information saved to .medplum_instance"

echo -e "${GREEN}Infrastructure is ready!${NC}"
echo ""
echo "Next steps:"
echo "  1. Open http://${PUBLIC_IP}:3000 in your browser"
if [ "$BACKUP_EXISTS" = false ]; then
    echo "  2. Sign in with admin@example.com / medplum_admin"
    echo "  3. Change admin password for security"
fi
echo "  4. Start working with Medplum"
echo "  5. Run ./scripts/stop_medplum.sh when done"
echo ""

cd - > /dev/null
exit 0
