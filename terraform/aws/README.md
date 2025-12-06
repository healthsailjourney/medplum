# Medplum AWS Development Environment - Terraform

This Terraform configuration creates a fully-configured AWS EC2 instance for Medplum development with sufficient resources.

## Architecture

- **Instance Type**: t3.xlarge (4 vCPUs, 16 GB RAM)
- **Storage**: 100 GB SSD (gp3)
- **OS**: Ubuntu 22.04 LTS
- **Network**: VPC with public subnet and Internet Gateway
- **Security**: Security group with configurable access controls

## Pre-installed Software

- Docker & Docker Compose
- Node.js 22.x (via nvm)
- Git
- VS Code Server (browser-based IDE)
- Build essentials

## Estimated Costs

| Instance Type | vCPUs | RAM   | Storage | Cost/Hour | Cost/Month (24/7) | Cost/Month (8h/day) |
|---------------|-------|-------|---------|-----------|-------------------|---------------------|
| t3.xlarge     | 4     | 16 GB | 100 GB  | $0.17     | ~$122             | ~$40                |
| t3.2xlarge    | 8     | 32 GB | 100 GB  | $0.33     | ~$240             | ~$80                |

*Note: Stop the instance when not in use to save costs!*

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```
3. **Terraform** installed (>= 1.0)
   ```bash
   brew install terraform  # macOS
   # or download from https://www.terraform.io/downloads
   ```
4. **SSH Key Pair** created in AWS
   ```bash
   # Create a new key pair
   aws ec2 create-key-pair --key-name medplum-dev --query 'KeyMaterial' --output text > ~/.ssh/medplum-dev.pem
   chmod 400 ~/.ssh/medplum-dev.pem
   ```

## Quick Start

### 1. Configure Variables

```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:
```hcl
aws_region     = "us-east-1"
key_pair_name  = "medplum-dev"  # Your AWS key pair name
instance_type  = "t3.xlarge"
use_elastic_ip = true

# Security: Replace with your actual IP
allowed_ssh_cidr = ["YOUR.IP.ADDRESS/32"]
allowed_app_cidr = ["YOUR.IP.ADDRESS/32"]
```

**To find your IP:**
```bash
curl ifconfig.me
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Apply Configuration

```bash
terraform apply
```

Type `yes` to confirm. This will take 5-10 minutes.

### 5. Get Connection Info

```bash
terraform output
```

You'll see:
- SSH command
- Instance public IP
- Medplum API URL
- Medplum Web URL
- VS Code Server URL

## Accessing Your Instance

### Option 1: SSH

```bash
# Use the SSH command from terraform output
ssh -i ~/.ssh/medplum-dev.pem ubuntu@<instance-ip>
```

### Option 2: VS Code Server (Browser)

1. Open: `http://<instance-ip>:8080`
2. Password: `medplum-dev-2024`

### Option 3: VS Code Remote SSH

1. Install "Remote - SSH" extension in VS Code
2. Add SSH config:
   ```
   Host medplum-dev
       HostName <instance-ip>
       User ubuntu
       IdentityFile ~/.ssh/medplum-dev.pem
   ```
3. Connect via VS Code

## Setting Up Medplum

### First Time Setup

SSH into the instance and run:

```bash
cd ~/medplum

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install dependencies (takes 5-10 minutes)
npm ci

# Build packages (takes 3-5 minutes)
npm run build:fast

# Start services
./start-medplum.sh
```

### Starting/Stopping Services

```bash
# Start
./start-medplum.sh

# Stop
./stop-medplum.sh

# View logs
tail -f /tmp/medplum-api.log
tail -f /tmp/medplum-app.log
```

### Accessing Medplum

- **Web App**: `http://<instance-ip>:3000`
- **API**: `http://<instance-ip>:8103`
- **Healthcheck**: `http://<instance-ip>:8103/healthcheck`

Default credentials:
- Email: `admin@example.com`
- Password: `medplum_admin`

## Managing Costs

### Stop Instance When Not in Use

```bash
# Stop instance (preserve data, stop billing for compute)
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)

# Start instance
aws ec2 start-instances --instance-ids $(terraform output -raw instance_id)

# Get new public IP (if not using Elastic IP)
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

### Destroy Everything

**Warning: This deletes all data!**

```bash
terraform destroy
```

## Customization

### Change Instance Type

Edit `terraform.tfvars`:
```hcl
instance_type = "t3.2xlarge"  # 8 vCPUs, 32 GB RAM
```

Then apply:
```bash
terraform apply
```

### Increase Storage

Edit `terraform.tfvars`:
```hcl
volume_size = 200  # GB
```

Then apply:
```bash
terraform apply
```

## Troubleshooting

### Cannot Connect via SSH

1. Check security group allows your IP:
   ```bash
   curl ifconfig.me  # Get your current IP
   ```
2. Update `allowed_ssh_cidr` in `terraform.tfvars`
3. Apply changes: `terraform apply`

### Instance Out of Memory

Monitor with:
```bash
htop
free -h
docker stats
```

Upgrade to larger instance type if needed.

### Medplum Services Not Starting

Check logs:
```bash
tail -f /tmp/medplum-api.log
tail -f /tmp/medplum-app.log
```

Check Docker:
```bash
docker-compose ps
docker-compose logs
```

### Port Already in Use

Stop existing services:
```bash
./stop-medplum.sh
pkill -f "tsx watch"
```

## Security Best Practices

1. **Restrict IP Access**: Always set `allowed_ssh_cidr` and `allowed_app_cidr` to your specific IP
2. **Change VS Code Password**: Edit `~/.config/code-server/config.yaml`
3. **Enable AWS CloudWatch**: Monitor instance metrics
4. **Regular Updates**: 
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```
5. **Use IAM Roles**: Don't store AWS credentials on the instance

## Monitoring

### System Resources

```bash
# CPU, Memory, Process monitoring
htop

# Disk usage
df -h

# Docker resources
docker stats

# Network connections
netstat -tulpn
```

### Application Logs

```bash
# API server
tail -f /tmp/medplum-api.log

# Web app
tail -f /tmp/medplum-app.log

# Docker services
docker-compose logs -f
```

## Backup

### Manual Backup

```bash
# Stop services
./stop-medplum.sh

# Create AMI of the instance
aws ec2 create-image \
  --instance-id $(terraform output -raw instance_id) \
  --name "medplum-dev-backup-$(date +%Y%m%d)" \
  --description "Medplum development environment backup"
```

### Automated Backups

Use AWS Backup service or create a cron job for regular snapshots.

## Alternative Configurations

### Spot Instances (Save ~70%)

Add to `main.tf`:
```hcl
resource "aws_spot_instance_request" "medplum_dev_spot" {
  # Same configuration as aws_instance
  # but much cheaper!
}
```

### Auto-Shutdown at Night

Add user data script:
```bash
# Shutdown at 8 PM daily
echo "0 20 * * * root shutdown -h now" >> /etc/crontab
```

## Support

- Medplum Docs: https://www.medplum.com/docs
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- AWS EC2 Pricing: https://aws.amazon.com/ec2/pricing/

## License

This Terraform configuration is provided as-is for Medplum development purposes.
