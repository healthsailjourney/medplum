#!/bin/bash

# Medplum Infrastructure Scale-Down Script
# This script scales down the Medplum infrastructure using Terraform
# Usage: ./scripts/scale_down.sh

set -e  # Exit on error

echo "=========================================="
echo "Medplum Infrastructure Scale-Down"
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

echo -e "${YELLOW}=========================================="
echo "WARNING: You are about to scale down infrastructure"
echo "==========================================${NC}"
echo ""
echo "This will:"
echo "  • Stop/destroy the EC2 instance"
echo "  • Reduce cost from ~$212/month to ~$22/month"
echo "  • Data will be preserved (EBS volume remains)"
echo ""

read -p "Do you want to continue? (yes/no) " -r CONFIRM

if [[ ! $CONFIRM =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Scale-down cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Step 1: Getting current instance details...${NC}"
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "N/A")
if [ "$INSTANCE_ID" = "N/A" ]; then
    echo -e "${RED}Error: Could not get instance ID${NC}"
    exit 1
fi
echo "Instance ID: $INSTANCE_ID"
echo ""

echo -e "${YELLOW}Step 2: Validating Terraform configuration...${NC}"
terraform validate
echo -e "${GREEN}✓ Configuration is valid${NC}"
echo ""

echo -e "${YELLOW}Step 3: Planning infrastructure changes...${NC}"
terraform plan -var="enable_instance=false" -out=tfplan_down
echo -e "${GREEN}✓ Plan created${NC}"
echo ""

echo -e "${YELLOW}Step 4: Applying scale-down (this will destroy resources)...${NC}"
terraform apply tfplan_down
echo -e "${GREEN}✓ Infrastructure scaled down${NC}"
echo ""

# Wait for instance to stop
echo -e "${YELLOW}Step 5: Waiting for instance to stop (30 seconds)...${NC}"
sleep 30
echo -e "${GREEN}✓ Shutdown complete${NC}"
echo ""

# Verify instance state
echo -e "${YELLOW}Step 6: Verifying instance is stopped...${NC}"
INSTANCE_STATE=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region ap-south-2 \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text 2>/dev/null || echo "unknown")

echo "Instance State: $INSTANCE_STATE"
echo ""

if [ "$INSTANCE_STATE" = "terminated" ] || [ "$INSTANCE_STATE" = "stopped" ]; then
    echo -e "${GREEN}=========================================="
    echo "Infrastructure Scaled Down Successfully!"
    echo "==========================================${NC}"
    echo ""
    echo "Cost Savings:"
    echo "  • Running cost: ~$7.06/day → $0.72/day"
    echo "  • Monthly savings: ~$190/month"
    echo "  • New monthly cost: ~$22 (EBS storage only)"
    echo ""
    echo -e "${YELLOW}To scale back up, run:${NC}"
    echo "  ./scripts/scale_up.sh"
    echo ""
    echo "Data Status:"
    if [ "$INSTANCE_STATE" = "stopped" ]; then
        echo "  • Instance is stopped (not terminated)"
        echo "  • All data is preserved"
        echo "  • Can be restarted with scale_up.sh"
    else
        echo "  • Instance is terminated"
        echo "  • EBS volume still exists with your data"
    fi
else
    echo -e "${RED}⚠ Unexpected instance state: $INSTANCE_STATE${NC}"
    echo "Please check AWS Console for details"
fi

# Clean up plan file
rm -f tfplan_down

echo ""
echo -e "${GREEN}Scale-down process complete!${NC}"
