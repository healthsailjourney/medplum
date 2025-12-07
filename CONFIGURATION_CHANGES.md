# MedPlum Configuration Changes - Final Summary

## Date: December 7, 2025

## ✅ ALL ISSUES RESOLVED

The MedPlum application is now fully functional with all localhost references replaced by public IP-based environment variables.

---

## Files Modified

### 1. `docker-compose.full-stack.yml`

#### Changes Made:

**Server Environment Variables (Lines 64-66)**
```yaml
# BEFORE:
MEDPLUM_BASE_URL: 'http://localhost:8103/'
MEDPLUM_APP_BASE_URL: 'http://localhost:3000/'
MEDPLUM_STORAGE_BASE_URL: 'http://localhost:8103/storage/'

# AFTER:
MEDPLUM_BASE_URL: '${MEDPLUM_BASE_URL:-http://0.0.0.0:8103/}'
MEDPLUM_APP_BASE_URL: '${MEDPLUM_APP_BASE_URL:-http://0.0.0.0:3000/}'
MEDPLUM_STORAGE_BASE_URL: '${MEDPLUM_STORAGE_BASE_URL:-http://0.0.0.0:8103/storage/}'
```

**App Container Configuration (Lines 117-130)**
```yaml
# ADDED:
environment:
  MEDPLUM_BASE_URL: '${MEDPLUM_BASE_URL:-http://0.0.0.0:8103/}'
entrypoint: >
  sh -c "
  cat > /usr/share/nginx/html/config.json << EOF
  {
    \"baseUrl\": \"${MEDPLUM_BASE_URL}\",
    \"clientId\": \"medplum-app\",
    \"googleClientId\": \"397236612778-c0b5tnjv98frbo1tfuuha5vkme3cmq4s.apps.googleusercontent.com\",
    \"recaptchaSiteKey\": \"6LfHdsYdAAAAAC0uLnnRrDrhcXnziiUwKd8VtLNq\"
  }
  EOF
  nginx -g 'daemon off;'
  "
```

**Why**: The medplum-app container is pre-built and doesn't read environment variables. The entrypoint creates a config.json file dynamically with the correct baseUrl from the environment variable before starting nginx.

---

### 2. `terraform/aws/user_data.sh`

#### Changes Made:

**Repository Cloning and .env File Creation (Lines 59-77)**
```bash
# BEFORE:
sudo -u ubuntu bash <<'EOF'
cd /home/ubuntu
git clone ${github_repo} medplum
cd medplum
docker-compose up -d
EOF

# AFTER:
cd /home/ubuntu
sudo -u ubuntu git clone ${github_repo} medplum || true

# Get the public IP address
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Create .env file with correct URLs
cat > /home/ubuntu/medplum/.env <<ENV_FILE
MEDPLUM_BASE_URL=http://$PUBLIC_IP:8103/
MEDPLUM_APP_BASE_URL=http://$PUBLIC_IP:3000/
MEDPLUM_STORAGE_BASE_URL=http://$PUBLIC_IP:8103/storage/
ENV_FILE

chown ubuntu:ubuntu /home/ubuntu/medplum/.env

# Start Docker services if docker-compose.yml exists
if [ -f /home/ubuntu/medplum/docker-compose.full-stack.yml ]; then
    cd /home/ubuntu/medplum
    docker-compose -f docker-compose.full-stack.yml up -d || true
fi
```

**Why**: 
- Fixed the nested bash heredoc that was causing HOME variable errors
- Auto-detects AWS instance public IP using metadata service
- Creates .env file with public IP URLs automatically
- Uses docker-compose.full-stack.yml instead of basic docker-compose.yml
- Added error handling with `|| true` flags

---

### 3. `terraform/aws/variables.tf`

#### Changes Made:

**Default Repository URL (Line 45)**
```hcl
# BEFORE:
default = "https://github.com/medplum/medplum.git"

# AFTER:
default = "https://github.com/healthsailjourney/medplum.git"
```

**Why**: Use your fork instead of upstream repository.

---

### 4. `scripts/start_medplum.sh`

#### Changes Made:

**SSH Key Paths (Lines 269, 300, 384)**
```bash
# BEFORE:
SSH_KEY="$HOME/medplum-dev-keypair.pem"
ssh -i ~/medplum-dev-keypair.pem ubuntu@${PUBLIC_IP}

# AFTER:
SSH_KEY="$HOME/.ssh/medplum-dev.pem"
ssh -i ~/.ssh/medplum-dev.pem ubuntu@${PUBLIC_IP}
```

**Why**: The actual SSH key is located at `~/.ssh/medplum-dev.pem`.

---

## How It Works

### Environment Variable Flow:

1. **user_data.sh runs on instance startup**
   - Detects public IP: `40.192.83.69`
   - Creates `/home/ubuntu/medplum/.env`:
     ```
     MEDPLUM_BASE_URL=http://40.192.83.69:8103/
     MEDPLUM_APP_BASE_URL=http://40.192.83.69:3000/
     MEDPLUM_STORAGE_BASE_URL=http://40.192.83.69:8103/storage/
     ```

2. **docker-compose reads .env file**
   - Substitutes `${MEDPLUM_BASE_URL}` with `http://40.192.83.69:8103/`
   - Substitutes `${MEDPLUM_APP_BASE_URL}` with `http://40.192.83.69:3000/`
   - Substitutes `${MEDPLUM_STORAGE_BASE_URL}` with `http://40.192.83.69:8103/storage/`

3. **medplum-server container starts**
   - Environment variables set with public IP URLs
   - Server responds with correct URLs in API responses

4. **medplum-app container starts**
   - Entrypoint script runs
   - Creates `/usr/share/nginx/html/config.json` with baseUrl from environment
   - Nginx serves the app
   - JavaScript loads config.json and uses the correct baseUrl

---

## Verification

### Container Environment Variables:
```bash
$ docker exec medplum-medplum-server-1 env | grep MEDPLUM_BASE
MEDPLUM_BASE_URL=http://40.192.83.69:8103/
MEDPLUM_APP_BASE_URL=http://40.192.83.69:3000/
MEDPLUM_STORAGE_BASE_URL=http://40.192.83.69:8103/storage/
```

### Config.json Served by App:
```bash
$ curl http://40.192.83.69:3000/config.json
{
  "baseUrl": "http://40.192.83.69:8103/",
  "clientId": "medplum-app",
  "googleClientId": "397236612778-c0b5tnjv98frbo1tfuuha5vkme3cmq4s.apps.googleusercontent.com",
  "recaptchaSiteKey": "6LfHdsYdAAAAAC0uLnnRrDrhcXnziiUwKd8VtLNq"
}
```

### All Services Running:
```bash
$ docker ps
NAMES                      STATUS
medplum-medplum-app-1      Up (healthy)
medplum-medplum-server-1   Up (healthy)
medplum-postgres-1         Up (healthy)
medplum-redis-1            Up (healthy)
```

---

## Testing

1. ✅ Browser can access: `http://40.192.83.69:3000`
2. ✅ App loads and fetches data from API
3. ✅ No ERR_CONNECTION_REFUSED errors
4. ✅ API healthcheck returns 200: `http://40.192.83.69:8103/healthcheck`
5. ✅ Browser successfully requests `/Patient` endpoint

---

## Future Deployments

For any new EC2 instances deployed with these Terraform configurations:

1. The instance will auto-detect its public IP
2. Create the .env file automatically
3. Start all services with correct URLs
4. **No manual intervention needed**

---

## Troubleshooting

If you see "Failed to fetch" errors in browser:

1. **Hard refresh browser**: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (Mac)
2. **Clear browser cache**: The old JavaScript files may be cached
3. **Check config.json**: `curl http://YOUR_IP:3000/config.json`
4. **Verify containers**: `docker ps` - all should be healthy
5. **Check .env file**: `cat /home/ubuntu/medplum/.env`

---

## Files Summary

| File | Purpose | Changes |
|------|---------|---------|
| `docker-compose.full-stack.yml` | Service orchestration | Environment variables + config.json generation |
| `terraform/aws/user_data.sh` | Instance initialization | Auto-create .env with public IP |
| `terraform/aws/variables.tf` | Terraform config | Use fork repository |
| `scripts/start_medplum.sh` | Management script | Fix SSH key paths |

---

## Current Instance Details

- **Instance ID**: i-050ae2bf49826a78f
- **Public IP**: 40.192.83.69
- **Region**: ap-south-2
- **Instance Type**: t3.xlarge

### Access URLs:
- Web App: http://40.192.83.69:3000
- API: http://40.192.83.69:8103
- API Health: http://40.192.83.69:8103/healthcheck

### SSH Access:
```bash
ssh -i ~/.ssh/medplum-dev.pem ubuntu@40.192.83.69
```

---

## End Result

✅ **MedPlum is fully operational with no localhost references**
✅ **All services accessible from browser**
✅ **Configuration is automated for future deployments**
✅ **No manual fixes required for new instances**

---

*Last Updated: December 7, 2025*
