# Medplum Troubleshooting Guide

## Issue 1: Web App Loads But Shows Errors in Console

### Symptoms
- Web app loads at `http://40.192.106.241:3000/`
- Browser console (F12) shows errors:
  ```
  POST http://localhost:8103/fhir/R4/$graphql net::ERR_CONNECTION_REFUSED
  ```
- API calls fail with connection refused

### Root Cause
Pre-built Medplum app has hardcoded `localhost:8103` in compiled JavaScript. Environment variables don't affect pre-built code.

### Solution

**Step 1: Restart app with nginx proxy**
```bash
source MEDPLUM_CONFIG.sh
restart_app_with_config
```

**Step 2: Hard refresh browser**
- Mac: `Cmd+Shift+R`
- Windows/Linux: `Ctrl+Shift+R`

**Step 3: Clear cache**
- Press `Ctrl+Shift+Delete`
- Select "All time"
- Clear all

**Step 4: Verify in console**
- Press `F12` to open console
- Check Network tab for successful API requests
- No `ERR_CONNECTION_REFUSED` errors

### Detailed Explanation
See `APP_CONFIGURATION_FIX.md` for complete technical details.

---

## Issue 2: Cannot SSH to Instance

### Symptoms
```
ssh: connect to host 40.192.106.241 port 22: Operation timed out
```

### Diagnosis

**Check 1: Verify instance is running**
```bash
# In AWS Console or AWS CLI
aws ec2 describe-instances --region ap-south-2 --query 'Reservations[].Instances[] | [?Tags[?Key==`Name` && Value==`medplum-dev`]].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}' --output table
```

**Check 2: Verify SSH key exists**
```bash
ls -la /Users/ramakrishnareddy/Downloads/medplum-dev-keypair.pem
# Should exist and have 400 permissions
```

**Check 3: Test connectivity with verbose output**
```bash
ssh -vvv -i /Users/ramakrishnareddy/Downloads/medplum-dev-keypair.pem ubuntu@40.192.106.241
```

### Solutions

**Solution A: Instance is stopped**
```bash
# In AWS Console:
# 1. Find instance
# 2. Instance State → Start Instance
# OR via Terraform:
cd terraform/aws
terraform apply -var='enable_instance=true'
```

**Solution B: Security group blocks SSH**
```bash
# In AWS Console:
# 1. Find Security Group "medplum-dev-sg"
# 2. Add Inbound rule: Port 22 (SSH), Source: Your IP
# OR check if already has 0.0.0.0/0 (open to all)
```

**Solution C: SSH key permissions wrong**
```bash
chmod 400 /Users/ramakrishnareddy/Downloads/medplum-dev-keypair.pem
```

**Solution D: IP changed**
```bash
# Instance might have new IP if EIP was removed
# Check AWS Console for actual IP
# Update MEDPLUM_CONFIG.sh:
export INSTANCE_IP="NEW_IP_ADDRESS"
```

---

## Issue 3: Docker Containers Not Running

### Symptoms
```bash
docker ps
# Returns empty or some containers missing
```

### Diagnosis

**Check all containers**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker ps -a"
```

**Check container logs**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker logs medplum-medplum-server-1 --tail 50"
```

### Solutions

**Solution A: Containers are stopped**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker-compose -f docker-compose.full-stack.yml up -d"
```

**Solution B: Container exited with error**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker logs medplum-medplum-server-1"
# Read error message and address specific issue
```

**Solution C: Restart all containers**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker-compose -f docker-compose.full-stack.yml down"
sleep 5
ssh_exec "docker-compose -f docker-compose.full-stack.yml up -d"
ssh_exec "sleep 10 && docker ps"
```

---

## Issue 4: API Server Unhealthy

### Symptoms
```bash
curl http://40.192.106.241:8103/healthcheck
# Connection refused or timeout
```

### Diagnosis

**Check container is running**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker ps | grep server"
```

**Check container logs**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker logs medplum-medplum-server-1 --tail 100"
```

**Check database connectivity**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec medplum-medplum-server-1 pg_isready -h postgres -U medplum"
```

**Check Redis connectivity**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec medplum-medplum-server-1 redis-cli -h redis ping"
```

### Solutions

**Solution A: Database not responding**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker ps | grep postgres"
# If not running:
ssh_exec "docker-compose -f docker-compose.full-stack.yml up -d medplum-postgres-1"
```

**Solution B: Redis not responding**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker ps | grep redis"
# If not running:
ssh_exec "docker-compose -f docker-compose.full-stack.yml up -d medplum-redis-1"
```

**Solution C: API server misconfiguration**
```bash
source MEDPLUM_CONFIG.sh
# Check environment variables in container
ssh_exec "docker inspect medplum-medplum-server-1 | grep -A 20 'Env'"
```

**Solution D: Restart API server**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker restart medplum-medplum-server-1"
sleep 10
ssh_exec "curl http://localhost:8103/healthcheck"
```

---

## Issue 5: Database Errors in Logs

### Symptoms
```
ERROR: relation "Patient" does not exist
ERROR: database connection failed
```

### Diagnosis

**Check database exists**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec medplum-postgres-1 psql -U medplum -l"
```

**Check tables exist**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec medplum-postgres-1 psql -U medplum -d medplum -c '\dt'"
```

### Solutions

**Solution A: Database not initialized**
```bash
source MEDPLUM_CONFIG.sh
# Recreate database
ssh_exec "docker exec medplum-postgres-1 dropdb -U medplum medplum"
ssh_exec "docker exec medplum-postgres-1 createdb -U medplum medplum"
# Restart server to reinitialize
ssh_exec "docker restart medplum-medplum-server-1"
```

**Solution B: Restore from backup**
```bash
# See DEPLOYMENT_GUIDE.md "Restore PostgreSQL" section
```

---

## Issue 6: High Memory Usage

### Symptoms
```bash
docker stats
# One or more containers using 80%+ memory
```

### Diagnosis

**Check memory limits**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker inspect medplum-medplum-server-1 | grep -A 5 'Memory'"
```

**Check application memory**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker top medplum-medplum-server-1"
```

### Solutions

**Solution A: Increase memory limit**
1. Edit `docker-compose.full-stack.yml`
2. Add `mem_limit: 2g` to container config
3. Restart: `docker-compose -f docker-compose.full-stack.yml down && up -d`

**Solution B: Check for memory leaks**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker logs medplum-medplum-server-1 | grep -i 'memory\|leak'"
```

**Solution C: Clear Redis cache**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec medplum-redis-1 redis-cli FLUSHALL"
```

---

## Issue 7: Nginx Proxy Not Working

### Symptoms
- App still tries to connect to localhost:8103
- Proxy_pass not being used

### Diagnosis

**Check nginx config in container**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec medplum-medplum-app-1 cat /etc/nginx/conf.d/default.conf | grep -A 5 'location /fhir/'"
```

Should show:
```nginx
location /fhir/ {
    proxy_pass http://40.192.106.241:8103;
```

**Check container is using correct image**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker inspect medplum-medplum-app-1 | grep Image"
```

### Solutions

**Solution A: Restart with correct config**
```bash
source MEDPLUM_CONFIG.sh
restart_app_with_config
```

**Solution B: Verify nginx is listening**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec medplum-medplum-app-1 netstat -tlnp | grep 3000"
```

**Solution C: Check nginx error log**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec medplum-medplum-app-1 tail -50 /var/log/nginx/error.log"
```

---

## Getting Help

### Collect Diagnostic Information

```bash
source MEDPLUM_CONFIG.sh

# Save all diagnostics to file
{
  echo "=== Date ==="
  date
  
  echo "=== Container Status ==="
  ssh_exec "docker ps -a"
  
  echo "=== Disk Usage ==="
  ssh_exec "df -h"
  
  echo "=== API Health ==="
  ssh_exec "curl -s http://localhost:8103/healthcheck || echo 'API not responding'"
  
  echo "=== Database Status ==="
  ssh_exec "docker exec medplum-postgres-1 pg_isready -U medplum || echo 'DB not responding'"
  
  echo "=== Redis Status ==="
  ssh_exec "docker exec medplum-redis-1 redis-cli ping || echo 'Redis not responding'"
  
  echo "=== Server Logs (last 30 lines) ==="
  ssh_exec "docker logs medplum-medplum-server-1 --tail 30"
  
  echo "=== App Logs (last 20 lines) ==="
  ssh_exec "docker logs medplum-medplum-app-1 --tail 20"
  
} | tee medplum_diagnostics.txt

# Review the diagnostic file
cat medplum_diagnostics.txt
```

### Common Error Patterns

| Error | Cause | Solution |
|-------|-------|----------|
| `net::ERR_CONNECTION_REFUSED` | App not using nginx proxy | Run `restart_app_with_config` |
| `timeout of 30000ms exceeded` | API server down or slow | Check `docker logs medplum-medplum-server-1` |
| `relation does not exist` | Database not initialized | Recreate database and restart |
| `connection refused` | Port not accessible | Check security group rules |
| `ECONNREFUSED` | Service not listening | Verify container is healthy |

### Additional Resources

- `DEPLOYMENT_GUIDE.md` - Complete operations manual
- `APP_CONFIGURATION_FIX.md` - App configuration details
- `FINAL_SOLUTION.md` - Nginx proxy explanation
- `MEDPLUM_CONFIG.sh` - Configuration and utility functions
