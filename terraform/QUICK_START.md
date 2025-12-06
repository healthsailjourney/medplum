# Medplum Cloud Development - Quick Start Guide

## 🚀 Deploy in 10 Minutes

This guide gets you from zero to a working Medplum development environment in the cloud.

## Prerequisites (5 minutes)

### 1. Install Tools

```bash
# macOS
brew install terraform awscli

# Verify installations
terraform version  # Should show v1.0+
aws --version      # Should show aws-cli/2.x
```

### 2. Configure AWS

```bash
# Sign up at https://aws.amazon.com (free tier available)
# Get your Access Key and Secret from AWS Console -> IAM

aws configure
# AWS Access Key ID: [paste your key]
# AWS Secret Access Key: [paste your secret]
# Default region name: us-east-1
# Default output format: json
```

### 3. Create SSH Key

```bash
aws ec2 create-key-pair \
  --key-name medplum-dev \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/medplum-dev.pem

chmod 400 ~/.ssh/medplum-dev.pem
```

## Deploy (5 minutes)

### 1. Configure

```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
```hcl
key_pair_name = "medplum-dev"
allowed_ssh_cidr = ["$(curl -s ifconfig.me)/32"]
allowed_app_cidr = ["$(curl -s ifconfig.me)/32"]
```

### 2. Deploy

```bash
terraform init
terraform apply
# Type: yes
```

**Wait 5-10 minutes** while AWS creates your instance.

### 3. Get Access Info

```bash
terraform output
```

Copy the `ssh_command` and URLs.

## Setup Medplum (10 minutes)

### 1. SSH to Instance

```bash
# Use the ssh_command from terraform output
ssh -i ~/.ssh/medplum-dev.pem ubuntu@<your-ip>
```

### 2. Install Dependencies

```bash
cd ~/medplum

# Load Node.js
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install (takes 5-10 minutes)
npm ci

# Build (takes 3-5 minutes)
npm run build:fast
```

### 3. Start Services

```bash
./start-medplum.sh
```

Wait 2-3 minutes for startup, then visit:
- **Web App**: http://\<your-ip\>:3000
- **Login**: admin@example.com / medplum_admin

## 🎉 You're Done!

You now have a fully working Medplum development environment.

## Daily Usage

### Start Your Dev Session

```bash
# Start instance (if stopped)
aws ec2 start-instances --instance-ids $(terraform output -raw instance_id)

# Wait 1 minute, then SSH
ssh -i ~/.ssh/medplum-dev.pem ubuntu@<your-ip>

# Start Medplum
cd ~/medplum
./start-medplum.sh

# Access: http://<your-ip>:3000
```

### Stop to Save Money

```bash
# Stop Medplum
./stop-medplum.sh

# Exit SSH
exit

# Stop instance (from your local machine)
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)
```

**Cost**: ~$1.36 per 8-hour day

## Development Options

### Option 1: Browser IDE (Easiest)

1. Open: http://\<your-ip\>:8080
2. Password: `medplum-dev-2024`
3. Open folder: `/home/ubuntu/medplum`
4. Start coding!

### Option 2: VS Code Remote SSH (Best)

1. Install "Remote - SSH" in VS Code
2. Add to `~/.ssh/config`:
   ```
   Host medplum
       HostName <your-ip>
       User ubuntu
       IdentityFile ~/.ssh/medplum-dev.pem
   ```
3. Connect: `Cmd+Shift+P` → "Remote-SSH: Connect to Host" → `medplum`

### Option 3: Local Editor + Git

1. Edit on instance via SSH
2. Commit and push to your fork
3. Pull locally to review

## Common Commands

```bash
# Monitor resources
htop

# View logs
tail -f /tmp/medplum-api.log
tail -f /tmp/medplum-app.log

# Check services
docker-compose ps
netstat -tulpn | grep -E '3000|8103'

# Restart services
./stop-medplum.sh
./start-medplum.sh
```

## Troubleshooting

### Can't Connect

```bash
# Update your IP in terraform.tfvars
allowed_ssh_cidr = ["$(curl -s ifconfig.me)/32"]

# Apply
terraform apply
```

### Services Won't Start

```bash
# Check logs
tail -f /tmp/medplum-api.log

# Restart Docker
docker-compose down
docker-compose up -d

# Try again
./start-medplum.sh
```

### Out of Disk Space

```bash
# Clean Docker
docker system prune -a

# Clean npm cache
npm cache clean --force
```

## Cost Management

| Usage Pattern | Hours/Month | Cost/Month |
|---------------|-------------|------------|
| 4 hrs/day, 5 days/week | 80 | ~$14 |
| 8 hrs/day, 5 days/week | 160 | ~$27 |
| 8 hrs/day, 7 days/week | 240 | ~$41 |
| 24/7 (not recommended) | 730 | ~$124 |

**Pro Tip**: Always stop the instance when not using it!

## Cleanup

**Delete everything** (when you're done with the project):

```bash
cd terraform/aws
terraform destroy
# Type: yes
```

## Next Steps

1. **Fork Medplum**: https://github.com/medplum/medplum
2. **Add your fork**:
   ```bash
   cd ~/medplum
   git remote add myfork https://github.com/YOUR_USERNAME/medplum.git
   ```
3. **Start developing!**

## Support

- Medplum Docs: https://www.medplum.com/docs
- Discord: https://discord.gg/medplum
- Detailed Guide: See `DEPLOYMENT_GUIDE.md`

---

**Questions?** Check the full `DEPLOYMENT_GUIDE.md` for detailed troubleshooting and advanced configurations.
