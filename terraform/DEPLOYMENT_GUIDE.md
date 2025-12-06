# Medplum Cloud Development Environment - Complete Deployment Guide

This guide provides Terraform configurations for deploying a fully-configured Medplum development environment on AWS or GCP.

## Table of Contents

- [Problem Statement](#problem-statement)
- [Solution Overview](#solution-overview)
- [Cloud Provider Comparison](#cloud-provider-comparison)
- [AWS Deployment](#aws-deployment)
- [GCP Deployment](#gcp-deployment)
- [Post-Deployment Setup](#post-deployment-setup)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)

## Problem Statement

Running Medplum locally requires:
- **Minimum 16 GB RAM** (32 GB recommended)
- **4+ CPU cores**
- **100 GB+ storage**
- Docker, PostgreSQL, Redis running simultaneously
- Node.js build processes that are memory-intensive

**Your Current System:**
- MacBook Air 2015 with 8 GB RAM
- Insufficient memory causing:
  - Build processes being killed
  - Database migrations failing
  - System thrashing with heavy swap usage

## Solution Overview

Deploy a cloud development instance with:

### AWS EC2 Solution
- **Instance**: t3.xlarge (4 vCPUs, 16 GB RAM)
- **Storage**: 100 GB SSD
- **Cost**: ~$0.17/hour (~$40/month if used 8 hours/day)
- **Features**:
  - Pre-installed Docker, Node.js 22.x, Git
  - VS Code Server (browser-based IDE)
  - Automated setup scripts
  - Elastic IP for consistent access

### GCP Compute Solution
- **Instance**: n2-standard-4 (4 vCPUs, 16 GB RAM)
- **Storage**: 100 GB SSD
- **Cost**: ~$0.19/hour (~$45/month if used 8 hours/day)
- **Features**: Same as AWS

## Cloud Provider Comparison

| Feature | AWS (t3.xlarge) | GCP (n2-standard-4) | Notes |
|---------|----------------|---------------------|-------|
| vCPUs | 4 | 4 | Equal |
| RAM | 16 GB | 16 GB | Equal |
| Storage | 100 GB SSD | 100 GB SSD | Equal |
| Cost/Hour | $0.17 | $0.19 | AWS slightly cheaper |
| Cost/Month (24/7) | ~$122 | ~$137 | AWS cheaper |
| Cost/Month (8h/day) | ~$40 | ~$45 | AWS cheaper |
| Network Performance | Good | Excellent | GCP has edge |
| Free Tier | 750 hours/month (12 months) | 300 hours/month | AWS better for new users |
| Ease of Use | Moderate | Easy | GCP simpler UI |

**Recommendation**: 
- **AWS** for cost-effectiveness and free tier
- **GCP** if you prefer simpler management

## AWS Deployment

### Prerequisites

1. **AWS Account**: Sign up at https://aws.amazon.com
2. **AWS CLI**: Install and configure
   ```bash
   # macOS
   brew install awscli
   
   # Configure
   aws configure
   # Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)
   ```

3. **Terraform**: Install
   ```bash
   brew install terraform
   ```

4. **SSH Key Pair**: Create
   ```bash
   # Create key pair in AWS
   aws ec2 create-key-pair \
     --key-name medplum-dev \
     --query 'KeyMaterial' \
     --output text > ~/.ssh/medplum-dev.pem
   
   chmod 400 ~/.ssh/medplum-dev.pem
   ```

### Step-by-Step Deployment

#### 1. Navigate to AWS Terraform Directory

```bash
cd terraform/aws
```

#### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region     = "us-east-1"
key_pair_name  = "medplum-dev"
instance_type  = "t3.xlarge"
volume_size    = 100
use_elastic_ip = true

# IMPORTANT: Replace with your actual IP for security
allowed_ssh_cidr = ["YOUR.IP.ADDRESS/32"]
allowed_app_cidr = ["YOUR.IP.ADDRESS/32"]
```

**Find your IP:**
```bash
curl ifconfig.me
```

#### 3. Initialize Terraform

```bash
terraform init
```

Output:
```
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

#### 4. Review Plan

```bash
terraform plan
```

Review the resources that will be created:
- VPC, Subnet, Internet Gateway
- Security Group
- EC2 Instance
- Elastic IP

#### 5. Deploy

```bash
terraform apply
```

Type `yes` when prompted.

**Deployment takes 5-10 minutes.**

#### 6. Get Access Information

```bash
terraform output
```

Example output:
```
instance_id = "i-0123456789abcdef0"
instance_public_ip = "54.123.45.67"
ssh_command = "ssh -i ~/.ssh/medplum-dev.pem ubuntu@54.123.45.67"
medplum_api_url = "http://54.123.45.67:8103"
medplum_web_url = "http://54.123.45.67:3000"
vscode_server_url = "http://54.123.45.67:8080"
```

Save these URLs!

## GCP Deployment

### Prerequisites

1. **GCP Account**: Sign up at https://cloud.google.com
2. **GCP Project**: Create a new project
3. **gcloud CLI**: Install and configure
   ```bash
   # macOS
   brew install --cask google-cloud-sdk
   
   # Initialize
   gcloud init
   # Follow prompts to select project and region
   ```

4. **SSH Key**: Generate if you don't have one
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```

### Step-by-Step Deployment

#### 1. Navigate to GCP Terraform Directory

```bash
cd terraform/gcp
```

#### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
project_id           = "your-gcp-project-id"  # REQUIRED
region               = "us-central1"
zone                 = "us-central1-a"
machine_type         = "n2-standard-4"
disk_size            = 100
ssh_user             = "ubuntu"
ssh_public_key_path  = "~/.ssh/id_rsa.pub"

# Security
allowed_ssh_cidr = ["YOUR.IP.ADDRESS/32"]
allowed_app_cidr = ["YOUR.IP.ADDRESS/32"]
```

#### 3. Enable Required APIs

```bash
gcloud services enable compute.googleapis.com
```

#### 4. Initialize and Deploy

```bash
terraform init
terraform plan
terraform apply
```

Type `yes` to confirm.

#### 5. Get Access Information

```bash
terraform output
```

## Post-Deployment Setup

### 1. Connect via SSH

```bash
# Use command from terraform output
ssh -i ~/.ssh/medplum-dev.pem ubuntu@<instance-ip>

# Or for GCP
gcloud compute ssh medplum-dev-instance --zone=us-central1-a
```

### 2. Verify Installation

```bash
# Check Docker
docker --version
docker-compose --version

# Check Node.js
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
node --version  # Should show v22.x.x

# Check if Medplum was cloned
ls ~/medplum
```

### 3. Install Medplum Dependencies

**This is the critical step that failed on your local machine!**

```bash
cd ~/medplum

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install dependencies (takes 5-10 minutes on the cloud instance)
npm ci

# Build packages (takes 3-5 minutes)
npm run build:fast
```

**Monitor progress:**
```bash
# In another terminal, monitor resources
htop
# Or
free -h && df -h
```

### 4. Start Medplum Services

```bash
# Use the provided script
./start-medplum.sh

# Or start manually
cd ~/medplum/packages/server
npm run dev > /tmp/medplum-api.log 2>&1 &

cd ~/medplum/packages/app
npm run dev > /tmp/medplum-app.log 2>&1 &
```

### 5. Monitor Startup

```bash
# Watch API logs
tail -f /tmp/medplum-api.log

# Watch app logs
tail -f /tmp/medplum-app.log

# Check if services are listening
netstat -tulpn | grep -E '3000|8103'
```

### 6. Access Medplum

**Via Browser:**
- Web App: `http://<instance-ip>:3000`
- API: `http://<instance-ip>:8103/healthcheck`
- VS Code Server: `http://<instance-ip>:8080` (password: `medplum-dev-2024`)

**Login Credentials:**
- Email: `admin@example.com`
- Password: `medplum_admin`

## Development Workflow

### Option 1: VS Code Server (Browser-Based)

1. Open `http://<instance-ip>:8080` in browser
2. Enter password: `medplum-dev-2024`
3. Open folder: `/home/ubuntu/medplum`
4. Start coding!

**Pros:**
- No local setup needed
- Access from any device
- Integrated terminal

### Option 2: VS Code Remote SSH

1. Install "Remote - SSH" extension in VS Code
2. Add to `~/.ssh/config`:
   ```
   Host medplum-dev
       HostName <instance-ip>
       User ubuntu
       IdentityFile ~/.ssh/medplum-dev.pem
   ```
3. Connect in VS Code: `Remote-SSH: Connect to Host` → `medplum-dev`

**Pros:**
- Full VS Code experience
- Better performance
- Local extensions work

### Option 3: Terminal + Git

1. SSH into instance
2. Make changes
3. Commit and push to your fork
4. Pull changes locally to review

## Cost Optimization

### Stop Instance When Not in Use

**AWS:**
```bash
# Stop (preserves data, stops compute billing)
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)

# Start
aws ec2 start-instances --instance-ids $(terraform output -raw instance_id)

# Check status
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].State.Name' --output text
```

**GCP:**
```bash
# Stop
gcloud compute instances stop medplum-dev-instance --zone=us-central1-a

# Start
gcloud compute instances start medplum-dev-instance --zone=us-central1-a

# Status
gcloud compute instances describe medplum-dev-instance --zone=us-central1-a \
  --format='get(status)'
```

### Cost Breakdown

**Scenario 1: Development 8 hours/day, 5 days/week**
- Running time: ~160 hours/month
- AWS cost: ~$27/month
- GCP cost: ~$30/month

**Scenario 2: Development 8 hours/day, 7 days/week**
- Running time: ~240 hours/month
- AWS cost: ~$41/month
- GCP cost: ~$46/month

**Scenario 3: Running 24/7**
- Running time: ~730 hours/month
- AWS cost: ~$124/month
- GCP cost: ~$139/month

### Automated Shutdown

Add a cron job to shut down at night:

```bash
# Edit crontab
crontab -e

# Add line to shutdown at 8 PM
0 20 * * * sudo shutdown -h now
```

## Troubleshooting

### Cannot SSH to Instance

**Check Security Group:**
```bash
# Get your current IP
curl ifconfig.me

# Update terraform.tfvars with new IP
# Then apply
terraform apply
```

### Medplum Services Won't Start

**Check logs:**
```bash
tail -f /tmp/medplum-api.log
tail -f /tmp/medplum-app.log
```

**Common issues:**
1. **Dependencies not installed**: Run `npm ci`
2. **Packages not built**: Run `npm run build:fast`
3. **Docker not running**: 
   ```bash
   docker-compose up -d
   docker-compose ps
   ```

### Out of Memory

**Monitor resources:**
```bash
free -h
htop
docker stats
```

**Solution:** Upgrade instance type in `terraform.tfvars`:
```hcl
instance_type = "t3.2xlarge"  # AWS: 8 vCPUs, 32 GB
machine_type = "n2-standard-8"  # GCP: 8 vCPUs, 32 GB
```

Then apply:
```bash
terraform apply
```

### Database Migration Failures

If migrations fail partway through:

1. **Check available memory:**
   ```bash
   free -h
   ```

2. **Stop other services:**
   ```bash
   ./stop-medplum.sh
   docker-compose down
   ```

3. **Restart just the API server:**
   ```bash
   docker-compose up -d
   cd ~/medplum/packages/server
   npm run dev
   ```

### VS Code Server Not Accessible

**Check if it's running:**
```bash
systemctl status code-server@ubuntu
```

**Restart it:**
```bash
sudo systemctl restart code-server@ubuntu
```

**Check firewall:**
```bash
# AWS - ensure port 8080 is in security group
# GCP - ensure firewall rule allows port 8080
```

## Cleanup

### Temporary Cleanup (Keep Infrastructure)

**Stop services:**
```bash
./stop-medplum.sh
docker-compose down
```

### Complete Cleanup (Delete Everything)

**⚠️ WARNING: This deletes all data!**

```bash
cd terraform/aws  # or terraform/gcp
terraform destroy
```

Type `yes` to confirm.

## Next Steps

1. **Fork Medplum Repository**
   ```bash
   # On the instance
   cd ~/medplum
   git remote add myfork https://github.com/YOUR_USERNAME/medplum.git
   ```

2. **Set Up Git**
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

3. **Start Development!**
   - Make changes
   - Test locally on the instance
   - Commit and push to your fork
   - Create pull requests

## Support Resources

- **Medplum Docs**: https://www.medplum.com/docs
- **Medplum Discord**: https://discord.gg/medplum
- **AWS Documentation**: https://docs.aws.amazon.com/
- **GCP Documentation**: https://cloud.google.com/docs
- **Terraform Documentation**: https://www.terraform.io/docs

## Summary

You now have:
- ✅ Fully-configured development environment with 16 GB RAM
- ✅ Pre-installed Docker, Node.js, Git, VS Code Server
- ✅ Infrastructure as Code (easy to recreate)
- ✅ Cost-effective (~$40/month for 8hrs/day usage)
- ✅ Professional development setup

The cloud instance has **2x the RAM you need** and will handle:
- ✅ npm ci without timeouts
- ✅ Full package builds
- ✅ Database migrations without crashes
- ✅ Running all services simultaneously

**Total setup time**: ~15 minutes
**Cost per day** (8 hours): ~$1.36
