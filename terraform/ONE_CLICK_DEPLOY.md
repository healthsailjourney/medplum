# One-Click Medplum Cloud Deployment 🚀

## What This Does

**Single script that deploys a complete Medplum development environment to AWS from any macOS machine.**

No manual configuration needed - the script handles everything!

## Features

✅ **Fully Automated**
- Installs prerequisites (Homebrew, Terraform, AWS CLI)
- Configures AWS credentials
- Creates SSH keys
- Deploys infrastructure
- Provides connection details

✅ **Works on Any Mac**
- Fresh macOS install ✓
- No prior setup needed ✓
- One command to run ✓

✅ **Complete Environment**
- 16 GB RAM, 4 vCPUs
- Docker, Node.js 22.x, Git pre-installed
- VS Code Server (browser IDE)
- Ready for Medplum development

## Quick Start

### 1. Prerequisites
- macOS computer
- AWS account ([sign up free](https://aws.amazon.com/free/))
- ~15 minutes

### 2. Run the Script

```bash
cd terraform
./deploy-medplum-cloud.sh
```

That's it! The script will:
1. ✓ Check and install tools (Homebrew, Terraform, AWS CLI)
2. ✓ Ask for your AWS credentials
3. ✓ Detect your IP for security
4. ✓ Create SSH keys
5. ✓ Deploy infrastructure to AWS
6. ✓ Provide all connection details

## What You'll Be Asked

### 1. AWS Credentials
```
AWS Access Key ID: [your-key]
AWS Secret Access Key: [your-secret]
Default region name: us-east-1
Default output format: json
```

Get these from: https://console.aws.amazon.com/iam/home#/security_credentials

### 2. Security Options
- Restrict access to your IP? (recommended: yes)

### 3. Deploy Confirmation
- Review costs and confirm deployment

## After Deployment

### You'll Receive:
- SSH connection command
- Instance IP address
- Web app URL
- API endpoint URL
- VS Code Server URL
- Complete setup instructions

### Connection Info Saved To:
`~/medplum-cloud-connection.txt`

## First Time Setup (on the instance)

```bash
# 1. SSH into instance (command provided by script)
ssh -i ~/.ssh/medplum-dev-XXXXX.pem ubuntu@<ip>

# 2. Wait 5 minutes for initial setup, then:
cd ~/medplum
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 3. Install dependencies (5-10 minutes)
npm ci

# 4. Build packages (3-5 minutes)
npm run build:fast

# 5. Start Medplum
./start-medplum.sh
```

### Then Access:
- **Web App**: http://\<ip\>:3000
- **VS Code**: http://\<ip\>:8080 (password: medplum-dev-2024)
- **Login**: admin@example.com / medplum_admin

## Daily Usage

### Start Your Day
```bash
# Start instance
aws ec2 start-instances --instance-ids <your-instance-id>

# Wait 1 minute, then SSH
ssh -i ~/.ssh/medplum-dev-XXXXX.pem ubuntu@<ip>

# Start Medplum
./start-medplum.sh

# Access: http://<ip>:3000
```

### End Your Day (Save Money!)
```bash
# Stop Medplum services
./stop-medplum.sh
exit

# Stop instance
aws ec2 stop-instances --instance-ids <your-instance-id>
```

## Costs

| Usage | Cost/Month |
|-------|------------|
| 8 hrs/day, 5 days/week | ~$27 |
| 8 hrs/day, 7 days/week | ~$41 |
| 24/7 (not recommended) | ~$124 |

**Free Tier**: New AWS accounts get 750 hours/month free for 12 months!

## Cleanup (When Done)

```bash
cd terraform/aws
terraform destroy
```

This deletes everything and stops all billing.

## Troubleshooting

### Script Fails to Install Homebrew
Run manually:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### AWS Credentials Invalid
1. Check your Access Key and Secret in AWS Console
2. Run: `aws configure` to re-enter them

### Can't Connect After Deployment
1. Wait 5 minutes for instance initialization
2. Check instance is running:
   ```bash
   aws ec2 describe-instances --instance-ids <id>
   ```

### Need to Update Your IP
Edit `terraform/aws/terraform.tfvars`:
```hcl
allowed_ssh_cidr = ["NEW.IP.ADDRESS/32"]
```
Then run: `cd terraform/aws && terraform apply`

## Advanced: Run from Different Mac

1. **Copy the script** to new Mac:
   ```bash
   scp terraform/deploy-medplum-cloud.sh newmac:~/
   ```

2. **Run it**:
   ```bash
   ./deploy-medplum-cloud.sh
   ```

3. **Use same AWS credentials** when prompted

The script will create a new SSH key for the new machine.

## Script Features

### Smart Detection
- ✓ Detects if tools already installed
- ✓ Auto-detects your public IP
- ✓ Verifies AWS credentials
- ✓ Checks for existing SSH keys

### Safe Defaults
- ✓ Restricts access to your IP
- ✓ Uses latest Ubuntu LTS
- ✓ Encrypts storage
- ✓ Cost-effective instance type

### User-Friendly
- ✓ Color-coded output
- ✓ Progress indicators
- ✓ Helpful error messages
- ✓ Saves all connection info

## What Gets Installed on the Instance

### Pre-installed
- Docker & Docker Compose
- Node.js 22.x (via nvm)
- Git, vim, htop
- VS Code Server
- PostgreSQL & Redis (via Docker)

### You Install (first time)
- Medplum dependencies (`npm ci`)
- Built packages (`npm run build:fast`)

## Files Created

### On Your Mac
- `~/.ssh/medplum-dev-XXXXX.pem` - SSH private key
- `~/medplum-cloud-connection.txt` - Connection details
- `terraform/aws/terraform.tfvars` - Terraform config

### In AWS
- VPC with public subnet
- Internet Gateway
- Security Group
- EC2 Instance (t3.xlarge)
- Elastic IP
- EBS Volume (100 GB)

## Comparison: Manual vs Script

| Task | Manual | Script |
|------|--------|--------|
| Install Homebrew | 5 min | Automatic |
| Install Terraform | 3 min | Automatic |
| Install AWS CLI | 3 min | Automatic |
| Configure AWS | 5 min | Guided |
| Create SSH key | 2 min | Automatic |
| Write Terraform config | 10 min | Automatic |
| Deploy infrastructure | 5 min | Automatic |
| **Total Time** | **30+ min** | **~10 min** |
| **Complexity** | High | Low |
| **Error-prone** | Yes | No |

## Summary

**One command deploys everything:**
```bash
./deploy-medplum-cloud.sh
```

**10-15 minutes later you have:**
- ✅ Professional development environment
- ✅ 16 GB RAM (vs your 8 GB MacBook)
- ✅ Browser-based IDE
- ✅ All connection details
- ✅ Ready to develop Medplum

**Cost:**
- ~$40/month (8 hours/day)
- Can be as low as $14/month (4 hours/day, 5 days/week)

**Perfect for:**
- Quick setup on any Mac
- Team onboarding
- Temporary development
- Testing Medplum

---

**Questions?** See the full guides:
- `QUICK_START.md` - Manual deployment
- `DEPLOYMENT_GUIDE.md` - Complete reference
- `CLOUD_SETUP_SUMMARY.md` - Overview
