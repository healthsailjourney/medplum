# Medplum App Configuration - Final Solution

## The Problem

The Medplum web app was loading but showing errors in the browser console:
```
POST http://localhost:8103/fhir/R4/$graphql net::ERR_CONNECTION_REFUSED
```

This occurred when accessing the app at `http://40.192.106.241:3000/`.

## Root Cause

The Medplum app is a **pre-built static frontend** (Vite-based React application) with hardcoded configuration for `localhost:8103`. 

When the app is built, URLs like `localhost:8103` are baked into the JavaScript bundle. Environment variables passed to the Docker container at runtime **do not affect already-compiled code**.

Result: Browser requests to the app at `40.192.106.241:3000` would try to connect back to `localhost:8103`, which doesn't exist, causing connection refused errors.

## The Solution: Nginx Proxy

Instead of trying to change the app's hardcoded configuration, we use an **nginx reverse proxy** inside the app container to intercept and forward API requests.

### How It Works

1. Browser loads app from `http://40.192.106.241:3000/`
2. App makes requests to `http://localhost:8103/fhir/...`
3. Nginx proxy intercepts requests to `localhost:8103`
4. Nginx forwards requests to actual server at `http://40.192.106.241:8103`
5. Response returns to browser

```
Browser → localhost:3000 (nginx)
           ↓
         localhost:3000/fhir/ (nginx intercepts)
           ↓
         40.192.106.241:8103 (actual API)
           ↓
         Response returns
```

## Implementation

### Nginx Configuration

```nginx
server {
    listen 3000;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Serve SPA - any route without file extension goes to index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests
    location /fhir/ {
        proxy_pass http://40.192.106.241:8103;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
    }
}
```

### Starting the App Container

Use the `restart_app_with_config()` function in MEDPLUM_CONFIG.sh:

```bash
source MEDPLUM_CONFIG.sh
restart_app_with_config
```

This function:
1. Creates `/tmp/nginx.conf` with proxy configuration
2. Stops the old app container
3. Starts new container with nginx.conf mounted as volume
4. Maps port 3000 to the nginx server

## Verification

After restarting with nginx proxy:

1. **Hard refresh browser:** `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)
2. **Clear cache:** `Ctrl+Shift+Delete` → select "All time"
3. **Visit:** `http://40.192.106.241:3000/`
4. **Check console:** Press `F12` and verify no connection errors
5. **Test API:** Should see successful API requests in Network tab

### Expected Results

- No `net::ERR_CONNECTION_REFUSED` errors
- API requests to `/fhir/` routes return successfully
- Web app loads and functions properly

## Why This Approach

| Approach | Pros | Cons |
|----------|------|------|
| **Environment Variables** | Clean, standard | Doesn't work with pre-built apps |
| **Rebuild Image** | Permanent solution | Time-consuming, requires Docker build |
| **Nginx Proxy** | Works immediately, non-invasive | Extra layer, nginx overhead |
| **DNS/Hosts File** | Local only, simple | Doesn't work for browsers on different machines |

We chose **Nginx Proxy** because:
- ✅ Works with pre-built image
- ✅ No need to rebuild
- ✅ Works from any machine/browser
- ✅ Minimal configuration changes
- ✅ Reversible if needed

## Troubleshooting

### Still seeing "localhost:8103" errors?

1. Verify app container is running with proxy:
   ```bash
   docker ps | grep app
   docker exec medplum-medplum-app-1 cat /etc/nginx/conf.d/default.conf | grep proxy_pass
   ```

2. Verify API server is reachable:
   ```bash
   curl http://40.192.106.241:8103/healthcheck
   ```

3. Clear all browser cache:
   - Chrome: Ctrl+Shift+Delete → "All time"
   - Firefox: Ctrl+Shift+Delete → "Everything"
   - Safari: Develop → Empty Web Storage

4. Check nginx error logs:
   ```bash
   docker exec medplum-medplum-app-1 tail -50 /var/log/nginx/error.log
   ```

## Important Notes

- **Always use `restart_app_with_config()`** - Don't use docker-compose directly for the app container
- **Never modify the pre-built image** - Just use nginx proxy as volume mount
- **The proxy config is temporary** - Stored in `/tmp/nginx.conf` on instance
- **CORS is handled** - Nginx forwards X-Forwarded-* headers automatically

## For Future Reference

If you need to change the API server IP or port:
1. Update INSTANCE_IP in MEDPLUM_CONFIG.sh
2. Run `restart_app_with_config()` again
3. The new IP will be used in the nginx proxy configuration
