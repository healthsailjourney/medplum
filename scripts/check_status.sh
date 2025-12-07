#!/bin/bash

# Medplum Infrastructure Status Check Script
# This script checks the current status of the Medplum infrastructure
# Usage: ./scripts/check_status.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}=========================================="
echo "Medplum Infrastructure Status Check"
echo "==========================================${NC}"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI is not installed${NC}"
    exit 1
fi

# Navigate to Terraform directory
SCRIPT_DIR="$(dirname "$0")"
TF_DIR="$SCRIPT_DIR/../terraform/aws"

if [ ! -d "$TF_DIR" ]; then
    echo -e "${RED}✗ Terraform directory not found: $TF_DIR${NC}"
    exit 1
fi

cd "$TF_DIR" || exit 1

# Check Terraform state
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}✗ Terraform state file not found. Have you run terraform init?${NC}"
    exit 1
fi

echo -e "${YELLOW}Checking Terraform state...${NC}"
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "N/A" ]; then
    echo -e "${RED}✗ Instance ID not found in Terraform state${NC}"
    echo "   This may mean: infrastructure has been destroyed or disabled"
    echo ""
    echo "Infrastructure Status: DISABLED/DESTROYED"
    echo ""
    echo -e "${YELLOW}To scale up, run:${NC}"
    echo "  ./scripts/scale_up.sh"
    exit 0
fi

echo -e "${GREEN}✓ Instance ID found: $INSTANCE_ID${NC}"
echo ""

# Get instance details from AWS
echo -e "${YELLOW}Checking AWS EC2 instance...${NC}"
INSTANCE_INFO=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region ap-south-2 \
  --query 'Reservations[0].Instances[0]' \
  --output json 2>/dev/null)

if [ -z "$INSTANCE_INFO" ] || [ "$INSTANCE_INFO" = "null" ]; then
    echo -e "${RED}✗ Instance not found in AWS${NC}"
    exit 1
fi

# Extract instance details
INSTANCE_STATE=$(echo "$INSTANCE_INFO" | grep -o '"State"[^}]*"Name":"[^"]*' | cut -d'"' -f6)
INSTANCE_TYPE=$(echo "$INSTANCE_INFO" | grep -o '"InstanceType":"[^"]*' | cut -d'"' -f4)
PUBLIC_IP=$(echo "$INSTANCE_INFO" | grep -o '"PublicIpAddress":"[^"]*' | cut -d'"' -f4)
PRIVATE_IP=$(echo "$INSTANCE_INFO" | grep -o '"PrivateIpAddress":"[^"]*' | cut -d'"' -f4)
LAUNCH_TIME=$(echo "$INSTANCE_INFO" | grep -o '"LaunchTime":"[^"]*' | cut -d'"' -f4)

echo ""
echo -e "${BLUE}Instance Details:${NC}"
echo "  Instance ID:    $INSTANCE_ID"
echo "  Instance Type:  $INSTANCE_TYPE"
echo "  State:          $INSTANCE_STATE"
echo "  Public IP:      ${PUBLIC_IP:-Not assigned}"
echo "  Private IP:     $PRIVATE_IP"
echo "  Launch Time:    $LAUNCH_TIME"
echo ""

# Check instance state and provide cost information
case "$INSTANCE_STATE" in
    "running")
        echo -e "${GREEN}✓ Instance is RUNNING${NC}"
        echo ""
        echo "Estimated Hourly Cost:  $0.294"
        echo "Estimated Daily Cost:   $7.06"
        echo "Estimated Monthly Cost: $212.64"
        echo ""

        # Check if services are accessible
        if [ -n "$PUBLIC_IP" ]; then
            echo -e "${YELLOW}Checking service availability...${NC}"

            # Check API
            API_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP:8103/healthcheck" 2>/dev/null)
            if [ "$API_CHECK" = "200" ]; then
                echo -e "${GREEN}✓ API Server: Accessible (http://$PUBLIC_IP:8103)${NC}"
            else
                echo -e "${YELLOW}✗ API Server: Not responding (HTTP $API_CHECK)${NC}"
                echo "   Services may still be starting..."
            fi

            # Check Web App
            WEB_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP:3000" 2>/dev/null)
            if [ "$WEB_CHECK" = "200" ]; then
                echo -e "${GREEN}✓ Web App: Accessible (http://$PUBLIC_IP:3000)${NC}"
            else
                echo -e "${YELLOW}✗ Web App: Not responding (HTTP $WEB_CHECK)${NC}"
                echo "   Services may still be starting..."
            fi

            echo ""
            echo "To access the instance:"
            echo "  ssh -i ~/medplum-dev-keypair.pem ubuntu@$PUBLIC_IP"
        fi

        echo ""
        echo -e "${YELLOW}To save costs, run:${NC}"
        echo "  ./scripts/scale_down.sh"
        ;;

    "stopped")
        echo -e "${YELLOW}⚠ Instance is STOPPED${NC}"
        echo ""
        echo "Estimated Hourly Cost:  $0.03 (EBS storage only)"
        echo "Estimated Daily Cost:   $0.72"
        echo "Estimated Monthly Cost: $21.60"
        echo ""
        echo "Data Status: Preserved (can be restarted)"
        echo ""
        echo -e "${YELLOW}To scale up, run:${NC}"
        echo "  ./scripts/scale_up.sh"
        ;;

    "stopping")
        echo -e "${YELLOW}⚠ Instance is STOPPING${NC}"
        echo "   Please wait and check again in a moment..."
        ;;

    "pending")
        echo -e "${YELLOW}⚠ Instance is STARTING${NC}"
        echo "   Services are still loading. Wait 2-3 minutes..."
        echo ""
        echo "Estimated Hourly Cost:  $0.294"
        echo "Estimated Daily Cost:   $7.06"
        echo "Estimated Monthly Cost: $212.64"
        ;;

    "terminated")
        echo -e "${RED}✗ Instance is TERMINATED${NC}"
        echo "   All services are offline"
        echo "   Data may be lost (check for EBS snapshots)"
        echo ""
        echo -e "${YELLOW}To redeploy, run:${NC}"
        echo "  ./scripts/scale_up.sh"
        ;;

    *)
        echo -e "${RED}✗ Unknown instance state: $INSTANCE_STATE${NC}"
        ;;
esac

echo ""

# Check Terraform variables
echo -e "${BLUE}Terraform Configuration:${NC}"
if [ -f "terraform.tfvars" ]; then
    REGION=$(grep 'aws_region' terraform.tfvars | grep -o '"[^"]*"' | tr -d '"')
    ENABLE_INSTANCE=$(grep 'enable_instance' terraform.tfvars | grep -o 'true\|false')

    if [ -n "$REGION" ]; then
        echo "  Region: $REGION"
    fi
    if [ -n "$ENABLE_INSTANCE" ]; then
        echo "  Instance Enabled: $ENABLE_INSTANCE"
    fi
fi

echo ""
echo -e "${BLUE}=========================================="
echo "Status Check Complete"
echo "==========================================${NC}"
echo ""
