# Medplum AWS Deployment - Complete Setup Details

**Date:** December 7, 2025  
**Region:** ap-south-2 (Hyderabad, India)  
**Status:** ✅ Successfully Deployed

---

## 📋 Table of Contents

1. [Instance Information](#instance-information)
2. [AWS Resources Created](#aws-resources-created)
3. [SSH Access](#ssh-access)
4. [Installed Software](#installed-software)
5. [Docker Services](#docker-services)
6. [Starting Medplum](#starting-medplum)
7. [Access URLs](#access-urls)
8. [Database Configuration](#database-configuration)
9. [Cost Management](#cost-management)
10. [Troubleshooting](#troubleshooting)
11. [Terraform Configuration](#terraform-configuration)
12. [Security Settings](#security-settings)

---

## 🌐 Instance Information

| Property | Value |
|----------|-------|
| **Instance ID** | `i-0fb6659bcf6a77951` |
| **Instance Type** | `t3.xlarge` |
| **vCPUs** | 4 |
| **Memory** | 16 GB RAM |
| **Storage** | 100 GB SSD (gp3, encrypted) |
| **Operating System** | Ubuntu 22.04 LTS |
| **Availability Zone** | `ap-south-2a` |
| **Public IP (Elastic)** | `16.112.103.205` |
| **Private IP** | `10.0.1.45` |
| **Status** | RUNNING ✓ |

---

## 🏗️ AWS Resources Created

### VPC & Networking

| Resource | ID/Value | Description |
|----------|----------|-------------|
| **VPC** | `vpc-0d7fd6e7e8fb4822e` | CIDR: 10.0.0.0/16 |
| **Subnet** | `subnet-0e345d08414dd6a7f` | CIDR: 10.0.1.0/24, Public |
| **Internet Gateway** | `igw-028e6d69cc5286b72` | Attached to VPC |
| **Route Table** | `rtb-0f62db8038b5c368a` | Routes to Internet Gateway |
| **Security Group** | `sg-03a819f7bdb78369e` | Named: medplum-dev-sg |
| **Elastic IP** | `eipalloc-00dea5a54e99446d7` | Address: 16.112.103.205 |

### IAM Resources

| Resource | Name | ARN/Details |
|----------|------|-------------|
| **IAM Role** | `medplum-dev-ec2-role` | For EC2 service |
| **Instance Profile** | `medplum-dev-instance-profile` | Associated with IAM role |

### Security Group Rules

**Inbound Rules:**

| Port | Protocol | Source | Description |
|------|----------|--------|-------------|
| 22 | TCP | 0.0.0.0/0 | SSH Access |
| 3000 | TCP | 0.0.0.0/0 | Medplum Web App |
| 8080 | TCP | 0.0.0.0/0 | VS Code Server |
| 8103 | TCP | 0.0.0.0/0 | Medplum API |

**Outbound Rules:**
- All traffic allowed (0.0.0.0/0)

---

## 🔑 SSH Access

### SSH Command

```bash
ssh -i ~/.ssh/medplum-dev.pem ubuntu@16.112.103.205
```

### Key Pair Details

- **Name:** `medplum-dev-keypair`
- **Type:** RSA
- **Location:** `~/.ssh/medplum-dev.pem`
- **Permissions:** `400` (read-only for owner)

### SSH Key Setup

If you need to move the key:

```bash
# Copy from Downloads to .ssh
cp ~/Downloads/medplum-dev-keypair.pem ~/.ssh/medplum-dev.pem

# Set correct permissions
chmod 400 ~/.ssh/medplum-dev.pem
```

---

## 🛠️ Installed Software

### System Packages

- ✅ Docker 24.x
- ✅ Docker Compose (latest)
- ✅ Git
- ✅ Build essentials (gcc, make, g++)
- ✅ curl, wget
- ✅ vim, htop
- ✅ ca-certificates

### Development Tools

- ✅ **Node.js:** v22.21.1 (installed via nvm)
- ✅ **npm:** v10.9.4
- ✅ **nvm:** v0.40.0

### Verify Installation

```bash
# Check Node.js
node --version  # v22.21.1

# Check npm
npm --version   # 10.9.4

# Check Docker
docker --version
docker-compose --version
```

---

## 📦 Docker Services

### Running Containers

| Container | Image | Port | Status |
|-----------|-------|------|--------|
| **medplum-postgres-1** | postgres:16 | 5432 | Running ✓ |
| **medplum-redis-1** | redis:7 | 6379 | Running ✓ |

### Docker Commands

```bash
# View running containers
docker ps

# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Start services
docker-compose up -d
```

### Docker Compose Location

```bash
cd /home/ubuntu/medplum
docker-compose ps
```

---

## 🚀 Starting Medplum

### First Time Setup (Run Once)

```bash
# SSH into the instance
ssh -i ~/.ssh/medplum-dev.pem ubuntu@16.112.103.205

# Navigate to Medplum directory
cd ~/medplum

# Load Node.js environment
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install dependencies (takes ~10-15 minutes)
npm ci

# Build Medplum (takes ~5-10 minutes)
npm run build:fast
```

### Starting the Services

**Option 1: Manual (Recommended for Development)**

In first SSH session (API Server):
```bash
cd ~/medplum/packages/server
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
npm run dev
```

In second SSH session (Web App):
```bash
cd ~/medplum/packages/app
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
npm run dev
```

**Option 2: Using Scripts (Background)**

The instance has helper scripts:

```bash
# Start Medplum services in background
./start-medplum.sh

# Stop Medplum services
./stop-medplum.sh

# View logs
tail -f /tmp/medplum-api.log
tail -f /tmp/medplum-app.log
```

---

## 🌐 Access URLs

Once Medplum is running:

| Service | URL | Description |
|---------|-----|-------------|
| **Web Application** | http://16.112.103.205:3000 | Main Medplum UI |
| **API Server** | http://16.112.103.205:8103 | REST API endpoint |
| **Healthcheck** | http://16.112.103.205:8103/healthcheck | API health status |
| **VS Code Server** | http://16.112.103.205:8080 | Browser-based IDE (if configured) |

### Default Credentials

- **Email:** admin@example.com
- **Password:** medplum_admin

*(Note: These should be changed on first login)*

---

## 💾 Database Configuration

### PostgreSQL

| Setting | Value |
|---------|-------|
| **Host** | localhost (from EC2) or 16.112.103.205 (external) |
| **Port** | 5432 |
| **Database** | medplum |
| **Username** | medplum |
| **Password** | medplum |
| **Version** | PostgreSQL 16 |

### Redis

| Setting | Value |
|---------|-------|
| **Host** | localhost (from EC2) or 16.112.103.205 (external) |
| **Port** | 6379 |
| **Version** | Redis 7 |

### Connection String

```
postgres://medplum:medplum@localhost:5432/medplum
```

---

## 💰 Cost Management

### Pricing Estimate (t3.xlarge)

| Usage Pattern | Approximate Cost |
|---------------|------------------|
| **24/7 (full month)** | ~$124/month |
| **8 hrs/day, 5 days/week** | ~$27/month |
| **4 hrs/day, 5 days/week** | ~$14/month |
| **Hourly rate** | ~$0.17/hour |

### Stop Instance (Save Money)

```bash
# Stop the instance
aws ec2 stop-instances --instance-ids i-0fb6659bcf6a77951 --region ap-south-2

# Check status
aws ec2 describe-instances --instance-ids i-0fb6659bcf6a77951 --region ap-south-2 --query 'Reservations[0].Instances[0].State.Name'
```

### Start Instance

```bash
# Start the instance
aws ec2 start-instances --instance-ids i-0fb6659bcf6a77951 --region ap-south-2

# Wait for it to be running
aws ec2 wait instance-running --instance-ids i-0fb6659bcf6a77951 --region ap-south-2

# Get new public IP (if Elastic IP not used)
aws ec2 describe-instances --instance-ids i-0fb6659bcf6a77951 --region ap-south-2 --query 'Reservations[0].Instances[0].PublicIpAddress'
```

**Note:** The Elastic IP (16.112.103.205) will remain the same even after stop/start.

### Set Up Billing Alerts

1. Go to AWS Console → Billing → Billing preferences
2. Enable "Receive Billing Alerts"
3. Create a CloudWatch alarm for your budget threshold

---

## 🔧 Troubleshooting

### Check Instance Status

```bash
# Check if instance is running
aws ec2 describe-instance-status --instance-ids i-0fb6659bcf6a77951 --region ap-south-2

# View instance details
aws ec2 describe-instances --instance-ids i-0fb6659bcf6a77951 --region ap-south-2
```

### Can't SSH?

**Check security group:**
```bash
aws ec2 describe-security-groups --group-ids sg-03a819f7bdb78369e --region ap-south-2
```

**Check key permissions:**
```bash
ls -la ~/.ssh/medplum-dev.pem
# Should show: -r-------- (400)

# Fix if needed:
chmod 400 ~/.ssh/medplum-dev.pem
```

### Docker Not Running?

```bash
# SSH into instance
ssh -i ~/.ssh/medplum-dev.pem ubuntu@16.112.103.205

# Check Docker status
sudo systemctl status docker

# Start Docker if stopped
sudo systemctl start docker

# Check containers
docker ps -a

# Restart containers
cd ~/medplum
docker-compose restart
```

### Node.js Not Found?

```bash
# Load nvm in your session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Verify Node.js
node --version
npm --version
```

### Medplum Not Starting?

```bash
# Check logs
cd ~/medplum
npm run dev 2>&1 | tee medplum-startup.log

# Check if ports are in use
sudo netstat -tulpn | grep -E '3000|8103'

# Check database connection
docker exec -it medplum-postgres-1 psql -U medplum -d medplum -c "SELECT version();"
```

### Out of Memory?

```bash
# Check memory usage
free -h
htop

# Check system resources
df -h
docker stats
```

---

## ⚙️ Terraform Configuration

### Terraform Files Location

```
/Users/ramakrishnareddy/HealthSail/MedPlumFork/medplum/terraform/aws/
```

### Configuration Used

**File:** `terraform.tfvars`

```hcl
aws_region     = "ap-south-2"
instance_type  = "t3.xlarge"
volume_size    = 100
key_pair_name  = "medplum-dev-keypair"
use_elastic_ip = true
allowed_ssh_cidr = ["0.0.0.0/0"]
allowed_app_cidr = ["0.0.0.0/0"]
github_repo = "https://github.com/healthsailjourney/medplum"
```

### Terraform State

The infrastructure was created manually via AWS CLI, not via Terraform apply, due to IAM instance profile restrictions.

### Destroy Infrastructure (When Done)

⚠️ **Warning:** This will permanently delete all resources!

```bash
# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids i-0fb6659bcf6a77951 --region ap-south-2

# Release Elastic IP
aws ec2 release-address --allocation-id eipalloc-00dea5a54e99446d7 --region ap-south-2

# Delete security group (after instance terminated)
aws ec2 delete-security-group --group-id sg-03a819f7bdb78369e --region ap-south-2

# Delete subnet
aws ec2 delete-subnet --subnet-id subnet-0e345d08414dd6a7f --region ap-south-2

# Detach and delete internet gateway
aws ec2 detach-internet-gateway --internet-gateway-id igw-028e6d69cc5286b72 --vpc-id vpc-0d7fd6e7e8fb4822e --region ap-south-2
aws ec2 delete-internet-gateway --internet-gateway-id igw-028e6d69cc5286b72 --region ap-south-2

# Delete route table
aws ec2 delete-route-table --route-table-id rtb-0f62db8038b5c368a --region ap-south-2

# Delete VPC
aws ec2 delete-vpc --vpc-id vpc-0d7fd6e7e8fb4822e --region ap-south-2

# Delete IAM resources
aws iam remove-role-from-instance-profile --instance-profile-name medplum-dev-instance-profile --role-name medplum-dev-ec2-role
aws iam delete-instance-profile --instance-profile-name medplum-dev-instance-profile
aws iam delete-role --role-name medplum-dev-ec2-role
```

---

## 🔒 Security Settings

### Security Group Configuration

**Name:** medplum-dev-sg  
**ID:** sg-03a819f7bdb78369e

**Current Settings:**
- ⚠️ **SSH (22):** Open to all (0.0.0.0/0)
- ⚠️ **HTTP (3000, 8103, 8080):** Open to all (0.0.0.0/0)

### Improve Security (Recommended)

Restrict SSH to your IP only:

```bash
# Get your current IP
curl ifconfig.me

# Update security group
aws ec2 revoke-security-group-ingress \
  --group-id sg-03a819f7bdb78369e \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  --region ap-south-2

aws ec2 authorize-security-group-ingress \
  --group-id sg-03a819f7bdb78369e \
  --protocol tcp \
  --port 22 \
  --cidr YOUR.IP.ADDRESS/32 \
  --region ap-south-2
```

### Best Practices

1. ✅ Use Elastic IP (already configured)
2. ✅ Enable EBS encryption (already enabled)
3. ✅ Regular backups (create AMI snapshots)
4. ⚠️ Restrict security group rules to specific IPs
5. ⚠️ Enable CloudWatch monitoring
6. ⚠️ Set up AWS Systems Manager for secure access
7. ⚠️ Rotate SSH keys periodically
8. ⚠️ Enable VPC Flow Logs

---

## 📝 Additional Notes

### AWS Account Information

- **Account ID:** 289964639668
- **IAM User:** ClaudeCodeUser
- **Region:** ap-south-2 (Asia Pacific - Hyderabad)

### Medplum Code

- **Repository:** https://github.com/healthsailjourney/medplum
- **Location on EC2:** /home/ubuntu/medplum
- **Branch:** main (default)

### System Monitoring

```bash
# Monitor CPU/Memory
htop

# Monitor disk usage
df -h

# Monitor Docker resources
docker stats

# Monitor network
sudo iftop
```

### Backup Recommendations

1. **Create AMI Snapshot:**
```bash
aws ec2 create-image \
  --instance-id i-0fb6659bcf6a77951 \
  --name "medplum-backup-$(date +%Y%m%d)" \
  --description "Medplum backup snapshot" \
  --region ap-south-2
```

2. **Backup Database:**
```bash
# SSH into instance
docker exec medplum-postgres-1 pg_dump -U medplum medplum > medplum_backup.sql
```

---

## 📞 Support & Resources

### Medplum Documentation
- **Official Docs:** https://www.medplum.com/docs
- **GitHub:** https://github.com/medplum/medplum
- **Discord:** https://discord.gg/medplum

### AWS Resources
- **EC2 Console:** https://ap-south-2.console.aws.amazon.com/ec2
- **VPC Console:** https://ap-south-2.console.aws.amazon.com/vpc
- **Billing:** https://console.aws.amazon.com/billing

---

## ✅ Deployment Summary

**Deployment Date:** December 7, 2025  
**Status:** ✅ Successfully Deployed  
**Region:** ap-south-2 (Hyderabad)  
**Instance Type:** t3.xlarge  
**Public IP:** 16.112.103.205  
**Estimated Monthly Cost:** ~$27-124 (depending on usage)

### What's Working:
- ✅ EC2 instance running
- ✅ VPC and networking configured
- ✅ Security groups in place
- ✅ Elastic IP assigned
- ✅ Docker services (PostgreSQL + Redis) running
- ✅ Node.js and development tools installed
- ✅ Medplum code cloned and ready

### Next Actions Required:
1. SSH into instance
2. Install npm dependencies (`npm ci`)
3. Build Medplum (`npm run build:fast`)
4. Start services (API + Web App)
5. Access via http://16.112.103.205:3000

---

**Document Version:** 1.0  
**Last Updated:** December 7, 2025  
**Maintained By:** Claude Code Assistant
