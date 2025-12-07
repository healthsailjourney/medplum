# Medplum Deployment & Operations Guide

## Quick Start

### Prerequisites
- AWS instance running at `40.192.106.241` (or update MEDPLUM_CONFIG.sh)
- SSH access with key at `/Users/ramakrishnareddy/Downloads/medplum-dev-keypair.pem`
- Docker and Docker Compose installed on instance
- AWS credentials configured locally

### Configuration

1. **Review MEDPLUM_CONFIG.sh**
   ```bash
   cat MEDPLUM_CONFIG.sh
   ```

2. **Update IP if different**
   ```bash
   # Edit MEDPLUM_CONFIG.sh and update INSTANCE_IP
   export INSTANCE_IP="YOUR_INSTANCE_IP"
   ```

3. **Validate configuration**
   ```bash
   source MEDPLUM_CONFIG.sh
   validate_config
   ```

## Starting Medplum

### Full Stack Start

```bash
# SSH to instance
ssh -i /Users/ramakrishnareddy/Downloads/medplum-dev-keypair.pem ubuntu@40.192.106.241

# Navigate to medplum directory
cd /path/to/medplum

# Start all services
docker-compose -f docker-compose.full-stack.yml up -d

# Verify all containers
docker ps --filter 'name=medplum'
```

### Expected Containers

```
medplum-postgres-1         Up 2 minutes (healthy)
medplum-redis-1            Up 2 minutes (healthy)
medplum-medplum-server-1   Up 2 minutes (healthy)
medplum-medplum-app-1      Up 2 minutes
```

### Configure App Container

**IMPORTANT:** After starting, always configure app with nginx proxy:

```bash
source MEDPLUM_CONFIG.sh
restart_app_with_config
```

This:
- Stops the old app container
- Creates nginx proxy configuration
- Starts app with proxy configuration
- Takes ~10 seconds

## Accessing Medplum

### Web App
- URL: `http://40.192.106.241:3000/`
- Browser: Hard refresh with `Cmd+Shift+R` or `Ctrl+Shift+R`
- Clear cache: `Ctrl+Shift+Delete` → "All time"

### API
- Base URL: `http://40.192.106.241:8103/`
- Health check: `curl http://40.192.106.241:8103/healthcheck`

## Stopping Medplum

### Stop All Services

```bash
# SSH to instance
ssh -i /path/to/key ubuntu@40.192.106.241

# Navigate to medplum directory
cd /path/to/medplum

# Stop all containers
docker-compose -f docker-compose.full-stack.yml down
```

### Verify Stopped

```bash
docker ps --filter 'name=medplum'
# Should return empty
```

## Database Management

### Backup PostgreSQL

```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec $DOCKER_POSTGRES_CONTAINER pg_dump -U $DB_USER $DB_NAME | gzip > /tmp/medplum_backup.sql.gz"
ssh_exec "cat /tmp/medplum_backup.sql.gz" > medplum_backup.sql.gz
```

### Restore PostgreSQL

```bash
# Copy backup to instance
scp -i $SSH_KEY medplum_backup.sql.gz ubuntu@$INSTANCE_IP:/tmp/

# SSH to instance and restore
source MEDPLUM_CONFIG.sh
ssh_exec "gunzip -c /tmp/medplum_backup.sql.gz | docker exec -i $DOCKER_POSTGRES_CONTAINER psql -U $DB_USER $DB_NAME"
```

### Access PostgreSQL CLI

```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec -it $DOCKER_POSTGRES_CONTAINER psql -U $DB_USER -d $DB_NAME"
```

## Redis Management

### Backup Redis

```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec $DOCKER_REDIS_CONTAINER redis-cli BGSAVE"
ssh_exec "docker exec $DOCKER_REDIS_CONTAINER redis-cli LASTSAVE"
```

### Access Redis CLI

```bash
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec -it $DOCKER_REDIS_CONTAINER redis-cli"
```

## Troubleshooting

### Web App Shows Errors

**Problem:** Browser console shows `net::ERR_CONNECTION_REFUSED` for localhost:8103

**Solution:**
```bash
source MEDPLUM_CONFIG.sh
restart_app_with_config
# Hard refresh browser with Cmd+Shift+R
```

See `APP_CONFIGURATION_FIX.md` for detailed explanation.

### Container Health Check Failed

```bash
# Check container status
docker ps

# Check container logs
docker logs medplum-medplum-server-1 --tail 100

# Restart container
docker restart medplum-medplum-server-1
```

### Cannot Connect to Instance

```bash
# Test SSH connectivity
ssh -i /Users/ramakrishnareddy/Downloads/medplum-dev-keypair.pem ubuntu@40.192.106.241 "echo Connected"

# Check security group allows port 22
# Check instance is running in AWS console
```

### API Not Responding

```bash
# Check API container is running
docker ps | grep server

# Check API logs
docker logs medplum-medplum-server-1 --tail 50

# Check database connectivity
docker exec medplum-medplum-server-1 curl http://postgres:5432

# Check Redis connectivity
docker exec medplum-medplum-server-1 redis-cli -h redis ping
```

## Monitoring

### Check Container Health

```bash
# Overall status
docker-compose -f docker-compose.full-stack.yml ps

# Individual container logs
docker logs -f medplum-medplum-server-1
docker logs -f medplum-postgres-1
docker logs -f medplum-redis-1
```

### Monitor Disk Usage

```bash
source MEDPLUM_CONFIG.sh
ssh_exec "df -h"
ssh_exec "du -sh /var/lib/docker/volumes/*"
```

### Check Network Connectivity

```bash
source MEDPLUM_CONFIG.sh
# From local machine
curl -I http://40.192.106.241:3000/
curl http://40.192.106.241:8103/healthcheck
```

## Cost Optimization

### Shutdown to Save Money

Using Terraform (from terraform/aws directory):

```bash
cd terraform/aws
terraform apply -var='enable_instance=false'
# Reduces cost from ~$212/month to ~$0.72/month
```

### Restart Instance

```bash
cd terraform/aws
terraform apply -var='enable_instance=true'
# Restarts instance and all services
```

## Performance Optimization

### Database Query Optimization

1. Check slow queries:
   ```bash
   source MEDPLUM_CONFIG.sh
   ssh_exec "docker exec $DOCKER_POSTGRES_CONTAINER psql -U $DB_USER -d $DB_NAME -c 'SELECT * FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;'"
   ```

2. Add indexes for frequently queried columns
3. Analyze explain plans

### Cache Optimization

```bash
# Clear Redis cache
source MEDPLUM_CONFIG.sh
ssh_exec "docker exec $DOCKER_REDIS_CONTAINER redis-cli FLUSHALL"

# Check Redis memory usage
ssh_exec "docker exec $DOCKER_REDIS_CONTAINER redis-cli INFO memory"
```

### Increase Resource Limits

1. Modify docker-compose.full-stack.yml
2. Set `mem_limit` and `cpus` for containers
3. Restart services: `docker-compose -f docker-compose.full-stack.yml down && docker-compose -f docker-compose.full-stack.yml up -d`

## Security Best Practices

### Update SSH Key

1. Generate new key pair
2. Add public key to `~/.ssh/authorized_keys` on instance
3. Update SSH_KEY in MEDPLUM_CONFIG.sh

### Update Passwords

Edit MEDPLUM_CONFIG.sh:
```bash
export DB_PASSWORD="new_secure_password"
export REDIS_PASSWORD="new_secure_password"
```

Then recreate containers with new environment.

### Restrict Security Group

In AWS Console or via Terraform:
- Remove 0.0.0.0/0 from ports 3000, 8103
- Add only specific IP ranges needed

## Emergency Procedures

### Reset Database

```bash
source MEDPLUM_CONFIG.sh

# Delete database
ssh_exec "docker exec $DOCKER_POSTGRES_CONTAINER dropdb -U $DB_USER $DB_NAME"

# Recreate database
ssh_exec "docker exec $DOCKER_POSTGRES_CONTAINER createdb -U $DB_USER $DB_NAME"

# Restart server
ssh_exec "docker restart $DOCKER_SERVER_CONTAINER"
```

### Clear All Data

```bash
source MEDPLUM_CONFIG.sh

# Clear database
ssh_exec "docker exec $DOCKER_POSTGRES_CONTAINER dropdb -U $DB_USER $DB_NAME"
ssh_exec "docker exec $DOCKER_POSTGRES_CONTAINER createdb -U $DB_USER $DB_NAME"

# Clear Redis
ssh_exec "docker exec $DOCKER_REDIS_CONTAINER redis-cli FLUSHALL"

# Restart
docker-compose -f docker-compose.full-stack.yml restart
```

## Support & Documentation

- `APP_CONFIGURATION_FIX.md` - App configuration issue explanation
- `FINAL_SOLUTION.md` - Nginx proxy solution details
- `TROUBLESHOOTING.md` - Detailed troubleshooting procedures
- `MEDPLUM_CONFIG.sh` - Configuration file with utility functions
