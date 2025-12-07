# MedPlum Configuration Fixes Applied

## Date: December 7, 2025

## ✅ ALL LOCALHOST REFERENCES REPLACED WITH PUBLIC IP

All hardcoded localhost URLs have been removed and replaced with environment variables based on the AWS public IP address.

## Issues Fixed

### 1. **Docker Compose Configuration - URL Configuration**
**Problem**: The web app was trying to connect to `localhost:8103` instead of the public IP address, causing `ERR_CONNECTION_REFUSED` errors in the browser.

**Files Modified**:
- `docker-compose.full-stack.yml`

**Changes**:
```yaml
# Changed from:
MEDPLUM_BASE_URL: 'http://localhost:8103/'
MEDPLUM_APP_BASE_URL: 'http://localhost:3000/'
MEDPLUM_STORAGE_BASE_URL: 'http://localhost:8103/storage/'

# Changed to:
MEDPLUM_BASE_URL: '${MEDPLUM_BASE_URL:-http://0.0.0.0:8103/}'
MEDPLUM_APP_BASE_URL: '${MEDPLUM_APP_BASE_URL:-http://0.0.0.0:3000/}'
MEDPLUM_STORAGE_BASE_URL: '${MEDPLUM_STORAGE_BASE_URL:-http://0.0.0.0:8103/storage/}'
```

**Result**: Now uses environment variables from `.env` file with public IP addresses.

---

### 2. **User Data Script - Repository Cloning**
**Problem**: The `user_data.sh` script had a `HOME` variable error and didn't properly clone the repository or start services.

**Files Modified**:
- `terraform/aws/user_data.sh`

**Changes**:
1. Fixed repository cloning by removing the nested bash block
2. Added automatic `.env` file creation with public IP
3. Changed to use `docker-compose.full-stack.yml` instead of basic `docker-compose.yml`
4. Added proper error handling with `|| true` flags

**New Code Added**:
```bash
# Get the public IP address
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Create .env file with correct URLs
cat > /home/ubuntu/medplum/.env <<ENV_FILE
MEDPLUM_BASE_URL=http://$PUBLIC_IP:8103/
MEDPLUM_APP_BASE_URL=http://$PUBLIC_IP:3000/
MEDPLUM_STORAGE_BASE_URL=http://$PUBLIC_IP:8103/storage/
ENV_FILE

chown ubuntu:ubuntu /home/ubuntu/medplum/.env
```

---

### 3. **SSH Key Path Corrections**
**Problem**: Scripts referenced wrong SSH key path (`medplum-dev-keypair.pem` instead of `.ssh/medplum-dev.pem`)

**Files Modified**:
- `scripts/start_medplum.sh` (3 locations)

**Changes**:
```bash
# Changed from:
SSH_KEY="$HOME/medplum-dev-keypair.pem"

# Changed to:
SSH_KEY="$HOME/.ssh/medplum-dev.pem"
```

**Locations Fixed**:
- Line 269: PostgreSQL backup restore
- Line 300: Redis backup restore  
- Line 384: SSH access instructions

---

### 4. **Terraform Variables - Repository URL**
**Problem**: Default repository pointed to upstream `medplum/medplum` instead of the fork `healthsailjourney/medplum`

**Files Modified**:
- `terraform/aws/variables.tf`

**Changes**:
```hcl
# Changed from:
default = "https://github.com/medplum/medplum.git"

# Changed to:
default = "https://github.com/healthsailjourney/medplum.git"
```

---

## Current Configuration

### Instance Details
- **Instance ID**: i-050ae2bf49826a78f
- **Public IP**: 40.192.83.69
- **Region**: ap-south-2
- **Instance Type**: t3.xlarge

### Services Running
✅ PostgreSQL (port 5432)
✅ Redis (port 6379)
✅ MedPlum API Server (port 8103)
✅ MedPlum Web App (port 3000)

### URLs
- **Web App**: http://40.192.83.69:3000
- **API**: http://40.192.83.69:8103
- **API Health**: http://40.192.83.69:8103/healthcheck

### Environment Variables (in .env file)
```
MEDPLUM_BASE_URL=http://40.192.83.69:8103/
MEDPLUM_APP_BASE_URL=http://40.192.83.69:3000/
MEDPLUM_STORAGE_BASE_URL=http://40.192.83.69:8103/storage/
```

---

## Testing Performed

1. ✅ API healthcheck returns HTTP 200
2. ✅ Web app loads correctly (HTTP 200)
3. ✅ Environment variables correctly set in containers
4. ✅ All Docker containers running and healthy
5. ✅ Services accessible from external browser

---

## Future Deployments

For new instances, the fixes in `user_data.sh` will automatically:
1. Clone the correct fork repository
2. Detect the public IP address
3. Create the `.env` file with correct URLs
4. Start the full stack with `docker-compose.full-stack.yml`

No manual intervention needed for URL configuration.

---

## Files Modified Summary

1. `docker-compose.full-stack.yml` - Environment variable support for URLs
2. `terraform/aws/user_data.sh` - Fixed cloning, added .env creation, fixed service startup
3. `terraform/aws/variables.tf` - Updated default repository to fork
4. `scripts/start_medplum.sh` - Fixed SSH key paths (3 locations)

All changes committed to local repository.
