#!/bin/bash

# Medplum Infrastructure Scale-Up Script
# This script scales up the Medplum infrastructure using Terraform
# Usage: ./scripts/scale_up.sh

set -e  # Exit on error

echo "=========================================="
echo "Medplum Infrastructure Scale-Up"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

# Navigate to Terraform directory
cd "$(dirname "$0")/../terraform/aws" || exit 1

echo -e "${YELLOW}Step 1: Validating Terraform configuration...${NC}"
terraform validate
echo -e "${GREEN}✓ Configuration is valid${NC}"
echo ""

echo -e "${YELLOW}Step 2: Planning infrastructure changes...${NC}"
terraform plan -var="enable_instance=true" -out=tfplan_up
echo -e "${GREEN}✓ Plan created${NC}"
echo ""

echo -e "${YELLOW}Step 3: Applying Terraform configuration...${NC}"
terraform apply tfplan_up
echo -e "${GREEN}✓ Infrastructure scaled up${NC}"
echo ""

# Wait for instance to be fully running
echo -e "${YELLOW}Step 4: Waiting for instance to be ready (30 seconds)...${NC}"
sleep 30
echo -e "${GREEN}✓ Instance should be ready${NC}"
echo ""

# Get instance details
echo -e "${YELLOW}Step 5: Retrieving instance details...${NC}"
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "N/A")
PUBLIC_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "N/A")
API_URL=$(terraform output -raw medplum_api_url 2>/dev/null || echo "N/A")
WEB_URL=$(terraform output -raw medplum_web_url 2>/dev/null || echo "N/A")

echo ""
echo -e "${GREEN}=========================================="
echo "Infrastructure Scaled Up Successfully!"
echo "==========================================${NC}"
echo ""
echo "Instance Details:"
echo "  Instance ID:  $INSTANCE_ID"
echo "  Public IP:    $PUBLIC_IP"
echo "  API URL:      $API_URL"
echo "  Web App URL:  $WEB_URL"
echo ""

# Check instance status
echo -e "${YELLOW}Step 6: Verifying instance is running...${NC}"
INSTANCE_STATE=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region ap-south-2 \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text 2>/dev/null || echo "unknown")

echo "Instance State: $INSTANCE_STATE"
echo ""

if [ "$INSTANCE_STATE" = "running" ]; then
    echo -e "${GREEN}✓ Instance is running${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. SSH into instance:"
    echo "   ssh -i ~/medplum-dev-keypair.pem ubuntu@$PUBLIC_IP"
    echo ""
    echo "2. Start services:"
    echo "   docker-compose up -d"
    echo "   cd ~/medplum/packages/server && npm run dev"
    echo "   cd ~/medplum/packages/app && npm run dev"
    echo ""
    echo "3. Access services:"
    echo "   API:     $API_URL/healthcheck"
    echo "   Web App: $WEB_URL"
    echo ""
else
    echo -e "${RED}⚠ Instance state is: $INSTANCE_STATE${NC}"
    echo "Please wait a moment and check AWS Console"
fi

# Clean up plan file
rm -f tfplan_up

echo -e "${GREEN}Scale-up process complete!${NC}"
