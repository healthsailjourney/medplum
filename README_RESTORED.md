# Medplum Deployment - Restored Files

## Overview

All essential Medplum deployment files have been restored. This document summarizes what was restored and provides quick access to critical information.

## Files Restored

### Configuration
- **MEDPLUM_CONFIG.sh** - Master configuration file with all settings and utility functions

### Documentation
- **APP_CONFIGURATION_FIX.md** - Technical explanation of app configuration issue
- **FINAL_SOLUTION.md** - Complete solution using nginx proxy
- **DEPLOYMENT_GUIDE.md** - Full operations and deployment manual
- **TROUBLESHOOTING.md** - Detailed troubleshooting for 7 common issues

### Scripts
- **scripts/backup_medplum.sh** - Backup PostgreSQL and Redis
- **scripts/restore_medplum.sh** - Restore from backups
- **scripts/list_backups.sh** - List available backups with details

## Quick Start

### 1. Update Configuration
```bash
cat MEDPLUM_CONFIG.sh
# Review and update INSTANCE_IP if different from 40.192.106.241
```

### 2. Verify Setup
```bash
source MEDPLUM_CONFIG.sh
validate_config
check_connectivity
```

### 3. Start Medplum
```bash
ssh -i /Users/ramakrishnareddy/Downloads/medplum-dev-keypair.pem ubuntu@40.192.106.241

# On instance:
cd /path/to/medplum
docker-compose -f docker-compose.full-stack.yml up -d

# Back on local machine:
source MEDPLUM_CONFIG.sh
restart_app_with_config
```

### 4. Access Medplum
- Web App: `http://40.192.106.241:3000/`
- API: `http://40.192.106.241:8103/`
- Health Check: `curl http://40.192.106.241:8103/healthcheck`

## Key Documents

### For Operations
Start with `DEPLOYMENT_GUIDE.md` for:
- Starting/stopping services
- Database management
- Monitoring
- Cost optimization
- Emergency procedures

### For Troubleshooting
Check `TROUBLESHOOTING.md` for solutions to:
1. Web app shows errors in console
2. Cannot SSH to instance
3. Docker containers not running
4. API server unhealthy
5. Database errors
6. High memory usage
7. Nginx proxy not working

### For Understanding the App Issue
Read `APP_CONFIGURATION_FIX.md` then `FINAL_SOLUTION.md` for:
- Why the app connects to localhost:8103
- Why environment variables don't work
- How the nginx proxy solution works
- How to apply and verify the fix

## Critical Information

### Instance Details
- **IP Address:** 40.192.106.241
- **SSH Key:** /Users/ramakrishnareddy/Downloads/medplum-dev-keypair.pem
- **SSH User:** ubuntu
- **SSH Port:** 22

### Ports
- **Web App:** 3000
- **API Server:** 8103
- **PostgreSQL:** 5432
- **Redis:** 6379

### Container Names
- `medplum-postgres-1` - PostgreSQL database
- `medplum-redis-1` - Redis cache
- `medplum-medplum-server-1` - API server
- `medplum-medplum-app-1` - Web app (with nginx proxy)

### Credentials
- **Database User:** medplum
- **Database Name:** medplum
- **Redis Password:** medplum
- See MEDPLUM_CONFIG.sh for all credentials

## Common Commands

### Check Status
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker ps --filter 'name=medplum'"
```

### View Logs
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker logs medplum-medplum-server-1 --tail 50"
```

### Restart App with Nginx Proxy
```bash
source MEDPLUM_CONFIG.sh
restart_app_with_config
```

### Backup Databases
```bash
./scripts/backup_medplum.sh
```

### List Backups
```bash
./scripts/list_backups.sh
```

### Restore from Backup
```bash
./scripts/restore_medplum.sh
```

## Known Issues & Solutions

### Issue: Web app shows "localhost:8103" errors

**Solution:**
```bash
source MEDPLUM_CONFIG.sh
restart_app_with_config
# Hard refresh browser: Cmd+Shift+R
```

See `APP_CONFIGURATION_FIX.md` for details.

### Issue: Cannot connect to instance

**Check:**
```bash
# 1. Instance is running
aws ec2 describe-instances --region ap-south-2

# 2. Security group allows SSH (port 22)
aws ec2 describe-security-groups --region ap-south-2 --group-names medplum-dev-sg

# 3. SSH key has correct permissions
chmod 400 /Users/ramakrishnareddy/Downloads/medplum-dev-keypair.pem
```

### Issue: API server not responding

**Check:**
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker ps | grep server"
ssh_exec "curl http://localhost:8103/healthcheck"
```

See `TROUBLESHOOTING.md` Issue 4 for detailed solutions.

## Next Steps

1. **Verify Configuration** - Ensure MEDPLUM_CONFIG.sh has correct values
2. **Test Connectivity** - Run `validate_config` and `check_connectivity`
3. **Start Services** - Use docker-compose to start all containers
4. **Configure App** - Run `restart_app_with_config` to fix app with nginx proxy
5. **Access Medplum** - Open web app and verify no console errors
6. **Set Up Backups** - Schedule regular backups with `backup_medplum.sh`

## File Locations

```
medplum/
├── MEDPLUM_CONFIG.sh              # Configuration & utility functions
├── APP_CONFIGURATION_FIX.md       # App config issue explanation
├── FINAL_SOLUTION.md              # Nginx proxy solution
├── DEPLOYMENT_GUIDE.md            # Full operations manual
├── TROUBLESHOOTING.md             # Troubleshooting guide
├── README_RESTORED.md             # This file
├── scripts/
│   ├── backup_medplum.sh          # Backup script
│   ├── restore_medplum.sh         # Restore script
│   └── list_backups.sh            # List backups script
├── docker-compose.full-stack.yml  # Docker Compose config
└── backups/                       # Backup storage location
    └── YYYYMMDD/
        ├── medplum_postgres_*.sql.gz
        └── medplum_redis_*.rdb.gz
```

## Support

### Quick Help
```bash
source MEDPLUM_CONFIG.sh

# Check connectivity
check_connectivity

# Validate configuration
validate_config

# Restart app with proxy
restart_app_with_config
```

### Detailed Diagnostics
```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker ps -a"
ssh_exec "docker logs medplum-medplum-server-1 --tail 100"
ssh_exec "curl http://localhost:8103/healthcheck"
```

### References
- See `DEPLOYMENT_GUIDE.md` for complete operations manual
- See `TROUBLESHOOTING.md` for issue-specific solutions
- See `APP_CONFIGURATION_FIX.md` for app configuration details

---

**Last Updated:** 2025-12-07
**Status:** All files restored and ready to use
