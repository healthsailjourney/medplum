#!/bin/bash

################################################################################
# Medplum Cloud Development Environment - One-Click Deployment Script
#
# This script automatically deploys a complete Medplum development environment
# to AWS from any macOS machine.
#
# What it does:
# 1. Checks/installs prerequisites (Homebrew, Terraform, AWS CLI)
# 2. Configures AWS credentials
# 3. Creates SSH key pair
# 4. Deploys infrastructure via Terraform
# 5. Provides access instructions
#
# Usage:
#   ./deploy-medplum-cloud.sh
#
# Requirements:
# - macOS
# - Internet connection
# - AWS account (free tier eligible)
#
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="us-east-1"
KEY_NAME="medplum-dev-$(date +%Y%m%d)"
INSTANCE_TYPE="t3.xlarge"
TERRAFORM_DIR="$SCRIPT_DIR/aws"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

prompt_yes_no() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

################################################################################
# Step 1: Welcome and Prerequisites Check
################################################################################

print_header "Medplum Cloud Development Environment Setup"

echo "This script will automatically deploy a complete Medplum development"
echo "environment to AWS with:"
echo ""
echo "  • 4 vCPUs, 16 GB RAM (t3.xlarge instance)"
echo "  • 100 GB SSD storage"
echo "  • Pre-configured with Docker, Node.js 22.x, Git"
echo "  • VS Code Server (browser-based IDE)"
echo "  • Estimated cost: ~\$40/month (8 hours/day usage)"
echo ""
echo "Prerequisites:"
echo "  • macOS"
echo "  • AWS account (free tier eligible for new accounts)"
echo "  • ~15 minutes of your time"
echo ""

if ! prompt_yes_no "Do you want to continue?"; then
    echo "Deployment cancelled."
    exit 0
fi

################################################################################
# Step 2: Check and Install Prerequisites
################################################################################

print_header "Checking Prerequisites"

# Check for Homebrew
if ! command_exists brew; then
    print_warning "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    print_success "Homebrew installed"
else
    print_success "Homebrew found"
fi

# Check for Terraform
if ! command_exists terraform; then
    print_warning "Terraform not found. Installing Terraform..."
    brew install terraform
    print_success "Terraform installed"
else
    print_success "Terraform found ($(terraform version | head -n1))"
fi

# Check for AWS CLI
if ! command_exists aws; then
    print_warning "AWS CLI not found. Installing AWS CLI..."
    brew install awscli
    print_success "AWS CLI installed"
else
    print_success "AWS CLI found ($(aws --version))"
fi

################################################################################
# Step 3: Configure AWS Credentials
################################################################################

print_header "AWS Configuration"

# Check if AWS is already configured
if aws sts get-caller-identity >/dev/null 2>&1; then
    print_success "AWS credentials already configured"
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_info "AWS Account: $AWS_ACCOUNT_ID"

    if ! prompt_yes_no "Do you want to use these credentials?"; then
        print_info "Reconfiguring AWS credentials..."
        aws configure
    fi
else
    print_warning "AWS credentials not configured"
    echo ""
    echo "You'll need your AWS Access Key ID and Secret Access Key."
    echo "Get them from: https://console.aws.amazon.com/iam/home#/security_credentials"
    echo ""
    read -p "Press Enter when you're ready to configure AWS..."
    aws configure

    # Verify configuration
    if aws sts get-caller-identity >/dev/null 2>&1; then
        print_success "AWS credentials configured successfully"
    else
        print_error "AWS configuration failed. Please check your credentials."
        exit 1
    fi
fi

################################################################################
# Step 4: Get User's IP Address
################################################################################

print_header "Security Configuration"

print_info "Getting your public IP address..."
USER_IP=$(curl -s ifconfig.me)
if [ -z "$USER_IP" ]; then
    print_error "Failed to detect your IP address"
    read -p "Please enter your public IP address: " USER_IP
fi
print_success "Your IP: $USER_IP"

if prompt_yes_no "Restrict SSH access to only your IP ($USER_IP)?"; then
    ALLOWED_SSH_CIDR="[\"$USER_IP/32\"]"
    ALLOWED_APP_CIDR="[\"$USER_IP/32\"]"
else
    print_warning "Opening SSH to all IPs (0.0.0.0/0) - Less secure!"
    ALLOWED_SSH_CIDR="[\"0.0.0.0/0\"]"
    ALLOWED_APP_CIDR="[\"0.0.0.0/0\"]"
fi

################################################################################
# Step 5: Create SSH Key Pair
################################################################################

print_header "SSH Key Setup"

SSH_KEY_PATH="$HOME/.ssh/$KEY_NAME.pem"

if [ -f "$SSH_KEY_PATH" ]; then
    print_warning "SSH key already exists: $SSH_KEY_PATH"
    if prompt_yes_no "Use existing key?"; then
        print_success "Using existing SSH key"
    else
        KEY_NAME="medplum-dev-$(date +%s)"
        SSH_KEY_PATH="$HOME/.ssh/$KEY_NAME.pem"
    fi
fi

if [ ! -f "$SSH_KEY_PATH" ]; then
    print_info "Creating AWS key pair: $KEY_NAME"

    # Create key pair in AWS
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --region "$AWS_REGION" \
        --query 'KeyMaterial' \
        --output text > "$SSH_KEY_PATH"

    chmod 400 "$SSH_KEY_PATH"
    print_success "SSH key created: $SSH_KEY_PATH"
fi

################################################################################
# Step 6: Create Terraform Configuration
################################################################################

print_header "Terraform Configuration"

# Navigate to terraform directory
cd "$TERRAFORM_DIR"

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
# Auto-generated by deploy-medplum-cloud.sh
# Generated: $(date)

aws_region     = "$AWS_REGION"
key_pair_name  = "$KEY_NAME"
instance_type  = "$INSTANCE_TYPE"
volume_size    = 100
use_elastic_ip = true

# Security: Restricted to your IP
allowed_ssh_cidr = $ALLOWED_SSH_CIDR
allowed_app_cidr = $ALLOWED_APP_CIDR

# GitHub repository
github_repo = "https://github.com/medplum/medplum.git"
EOF

print_success "Terraform configuration created"

################################################################################
# Step 7: Initialize and Deploy Terraform
################################################################################

print_header "Deploying Infrastructure to AWS"

print_info "Initializing Terraform..."
terraform init > /dev/null 2>&1
print_success "Terraform initialized"

print_info "Planning deployment..."
terraform plan -out=tfplan > /dev/null 2>&1
print_success "Deployment plan created"

echo ""
echo "Ready to deploy the following resources:"
echo "  • VPC and networking components"
echo "  • Security groups (ports 22, 3000, 8080, 8103)"
echo "  • EC2 instance (t3.xlarge - 4 vCPUs, 16 GB RAM)"
echo "  • 100 GB SSD storage"
echo "  • Elastic IP address"
echo ""
echo "Estimated cost: ~\$0.17/hour (~\$40/month for 8hrs/day)"
echo ""

if ! prompt_yes_no "Deploy now?"; then
    echo "Deployment cancelled. Run 'terraform apply' manually to deploy."
    exit 0
fi

print_info "Deploying infrastructure... (this takes 5-10 minutes)"
terraform apply tfplan

if [ $? -eq 0 ]; then
    print_success "Infrastructure deployed successfully!"
else
    print_error "Deployment failed. Check errors above."
    exit 1
fi

################################################################################
# Step 8: Get Outputs and Display Access Information
################################################################################

print_header "Deployment Complete! 🎉"

# Get outputs
INSTANCE_ID=$(terraform output -raw instance_id)
INSTANCE_IP=$(terraform output -raw instance_public_ip)
SSH_COMMAND=$(terraform output -raw ssh_command)
API_URL=$(terraform output -raw medplum_api_url)
WEB_URL=$(terraform output -raw medplum_web_url)
VSCODE_URL=$(terraform output -raw vscode_server_url)

# Create a connection info file
CONNECTION_INFO_FILE="$HOME/medplum-cloud-connection.txt"
cat > "$CONNECTION_INFO_FILE" <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Medplum Cloud Development Environment - Connection Info
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Created: $(date)
Instance ID: $INSTANCE_ID
Public IP: $INSTANCE_IP

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SSH ACCESS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SSH Command:
  $SSH_COMMAND

Alternative SSH (short):
  ssh ubuntu@$INSTANCE_IP -i $SSH_KEY_PATH

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SETUP MEDPLUM (First Time Only)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. SSH into the instance:
   $SSH_COMMAND

2. Wait 5 minutes for initial setup to complete, then run:
   cd ~/medplum
   export NVM_DIR="\$HOME/.nvm"
   [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
   npm ci                    # Takes 5-10 minutes
   npm run build:fast        # Takes 3-5 minutes

3. Start Medplum:
   ./start-medplum.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ACCESS MEDPLUM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Web Application:    $WEB_URL
API Endpoint:       $API_URL
VS Code Server:     $VSCODE_URL

Default Login:
  Email:    admin@example.com
  Password: medplum_admin

VS Code Server Password:
  medplum-dev-2024

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DAILY USAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Start instance:
  aws ec2 start-instances --instance-ids $INSTANCE_ID

Stop instance (save money!):
  aws ec2 stop-instances --instance-ids $INSTANCE_ID

Check instance status:
  aws ec2 describe-instances --instance-ids $INSTANCE_ID \\
    --query 'Reservations[0].Instances[0].State.Name' --output text

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  COSTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Running:  ~\$0.17/hour
8hrs/day: ~\$40/month
24/7:     ~\$124/month

TIP: Always stop the instance when not using it!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DESTROY INFRASTRUCTURE (when done)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

From: $TERRAFORM_DIR

Command:
  terraform destroy

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This file saved to: $CONNECTION_INFO_FILE

EOF

# Display the connection info
cat "$CONNECTION_INFO_FILE"

echo ""
print_success "Connection info saved to: $CONNECTION_INFO_FILE"
echo ""

################################################################################
# Step 9: Offer to SSH Immediately
################################################################################

if prompt_yes_no "Do you want to SSH into the instance now?"; then
    echo ""
    print_info "Connecting to instance..."
    print_warning "Note: Initial setup is still running. It may take 5 minutes to complete."
    echo ""
    exec ssh -i "$SSH_KEY_PATH" ubuntu@"$INSTANCE_IP"
else
    echo ""
    print_info "To connect later, use:"
    echo "  ssh -i $SSH_KEY_PATH ubuntu@$INSTANCE_IP"
    echo ""
fi

################################################################################
# Done!
################################################################################

print_success "All done! Happy coding! 🚀"
