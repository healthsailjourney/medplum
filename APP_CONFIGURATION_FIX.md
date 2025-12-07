# Medplum App Configuration Issue & Fix

## Summary

The Medplum web app (pre-built static frontend) has hardcoded `localhost:8103` URLs that cannot be changed via environment variables. Solution: Use nginx reverse proxy to intercept and forward API requests.

## The Issue

### What Happens
1. User deploys Medplum on instance at `40.192.106.241`
2. Opens web app at `http://40.192.106.241:3000/`
3. App loads successfully
4. App makes API request to `http://localhost:8103/fhir/...`
5. Browser shows: `net::ERR_CONNECTION_REFUSED`

### Why It Happens

The Medplum app is a **Vite-built React SPA** with pre-compiled JavaScript. During build time, URLs are hardcoded:

```javascript
// In the built JavaScript:
const API_URL = 'http://localhost:8103';  // <-- Hardcoded!
fetch(`${API_URL}/fhir/R4/...`);
```

When you pass environment variables to Docker at runtime:
```bash
docker run -e MEDPLUM_BASE_URL=http://40.192.106.241:8103 ...
```

These variables are **only available to the Node.js process**, not to the pre-built JavaScript in the browser. The JavaScript has already been compiled and doesn't read environment variables.

## Why Environment Variables Don't Work

### Attempt 1: Direct Environment Variables
```bash
docker run -e MEDPLUM_BASE_URL=http://40.192.106.241:8103 medplum/medplum-app:latest
# ❌ Doesn't work - JavaScript doesn't read env vars
```

### Attempt 2: Docker-Compose Environment
```yaml
services:
  app:
    environment:
      MEDPLUM_BASE_URL: http://40.192.106.241:8103
# ❌ Doesn't work - app is pre-built static frontend
```

### Attempt 3: Build-Time Variables
```bash
docker build --build-arg MEDPLUM_BASE_URL=... 
# ❌ We don't have the source - using pre-built image
```

## The Solution: Nginx Reverse Proxy

Instead of trying to change the app's configuration, use nginx to **intercept and redirect** requests:

```
Browser Request to localhost:8103
    ↓
Nginx sees request to /fhir/
    ↓
Nginx forwards to 40.192.106.241:8103
    ↓
API server responds
    ↓
Nginx returns response to browser
```

### Nginx Configuration

The key configuration in `/etc/nginx/conf.d/default.conf`:

```nginx
location /fhir/ {
    proxy_pass http://40.192.106.241:8103;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_buffering off;
}
```

## How to Apply This Fix

### Using MEDPLUM_CONFIG.sh

```bash
source MEDPLUM_CONFIG.sh
restart_app_with_config
```

This function:
1. Stops current app container
2. Creates nginx config with correct IP/port
3. Starts new container with config mounted
4. Returns in ~10 seconds

### Manual Approach

```bash
# 1. Create nginx config
cat > /tmp/nginx.conf << 'EOF'
server {
    listen 3000;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /fhir/ {
        proxy_pass http://40.192.106.241:8103;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
    }
}
EOF

# 2. Stop old container
docker stop medplum-medplum-app-1
docker rm medplum-medplum-app-1

# 3. Start with nginx config
docker run -d \
  --name medplum-medplum-app-1 \
  --restart always \
  -p 3000:3000 \
  -v /tmp/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  medplum/medplum-app:latest
```

## Verification

After applying the fix:

```bash
# 1. Check container is running
docker ps | grep app

# 2. Verify nginx config is loaded
docker exec medplum-medplum-app-1 cat /etc/nginx/conf.d/default.conf

# 3. Test proxy works
docker exec medplum-medplum-app-1 curl http://localhost:3000/

# 4. In browser:
#    - Hard refresh: Cmd+Shift+R
#    - Clear cache: Ctrl+Shift+Delete
#    - Visit: http://40.192.106.241:3000
#    - Check console (F12) for errors
```

## Why This Works

- ✅ **Doesn't require rebuilding image** - Works with pre-built image
- ✅ **Doesn't require changing code** - Pure infrastructure solution
- ✅ **Works from any network** - Works for any client machine
- ✅ **Proper headers** - Forwards X-Forwarded-* headers for API
- ✅ **Reversible** - Just delete config and restart without it

## Important Notes

1. **The proxy only affects this specific container** - Other deployments unaffected
2. **Configuration is temporary** - Stored in `/tmp/nginx.conf`
3. **Always use `restart_app_with_config()`** - Ensures correct config is applied
4. **Don't mix approaches** - Use either nginx OR docker-compose, not both for app container

## Related Files

- `MEDPLUM_CONFIG.sh` - Contains `restart_app_with_config()` function
- `FINAL_SOLUTION.md` - Detailed explanation of solution
- `DEPLOYMENT_GUIDE.md` - Full operations manual
