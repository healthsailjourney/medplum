# One-Click Medplum Local Setup for Mac 🚀

## What This Does

**Single script that sets up complete Medplum development environment on any Mac with sufficient RAM.**

No cloud needed - everything runs locally!

## Requirements

### Minimum System Requirements
- ✅ macOS Big Sur (11.0) or later
- ✅ **16 GB RAM minimum** (32 GB recommended)
- ✅ 50 GB free disk space
- ✅ Admin privileges
- ✅ Internet connection

### Check Your System

```bash
# Check RAM
sysctl hw.memsize | awk '{print $2/1024/1024/1024 " GB"}'

# Check free disk space
df -h ~
```

## Quick Start

### One-Command Installation

```bash
./setup-medplum-local.sh
```

That's it! The script will:
1. ✅ Check system requirements
2. ✅ Install Homebrew (if needed)
3. ✅ Install Node.js 22.x via nvm
4. ✅ Install Docker Desktop (if needed)
5. ✅ Clone Medplum repository
6. ✅ Install all dependencies
7. ✅ Build all packages
8. ✅ Start Docker services
9. ✅ Create start/stop helper scripts
10. ✅ Optionally start Medplum

**Total Time**: 30-45 minutes

## What Gets Installed

### System Tools
- **Homebrew** - Package manager
- **nvm** - Node.js version manager
- **Node.js 22.x** - JavaScript runtime
- **Docker Desktop** - Container platform
- **Git** - Version control

### Medplum Components
- **PostgreSQL** - Database (via Docker)
- **Redis** - Cache (via Docker)
- **Medplum API Server** - Backend
- **Medplum Web App** - Frontend
- **All dependencies** - npm packages

### Helper Scripts
- `~/medplum/start-medplum.sh` - Start all services
- `~/medplum/stop-medplum.sh` - Stop all services

## After Installation

### Start Medplum

```bash
~/medplum/start-medplum.sh
```

Wait 2-3 minutes for services to fully start.

### Access Medplum

- **Web App**: http://localhost:3000
- **API**: http://localhost:8103/healthcheck

**Login**:
- Email: `admin@example.com`
- Password: `medplum_admin`

### Stop Medplum

```bash
~/medplum/stop-medplum.sh
```

## Daily Workflow

### Morning

```bash
# Start Medplum
~/medplum/start-medplum.sh

# Wait 2-3 minutes, then open browser
open http://localhost:3000
```

### During Development

```bash
# Monitor logs
tail -f /tmp/medplum-api.log
tail -f /tmp/medplum-app.log

# Check Docker services
docker-compose ps
```

### Evening

```bash
# Stop services to free up resources
~/medplum/stop-medplum.sh
```

## System Requirements Check

The script automatically checks:

### RAM Check
- **Minimum**: 12 GB (will warn)
- **Recommended**: 16 GB
- **Ideal**: 32 GB

**If you have less than 16 GB**: Script will warn but allow you to continue. You may experience:
- Slower build times
- Database migration issues
- npm install timeouts

### Disk Space Check
- **Minimum**: 50 GB free
- **Recommended**: 100 GB free

Components use approximately:
- Node.js & dependencies: ~15 GB
- Docker images: ~5 GB
- Medplum builds: ~10 GB
- Development files: ~10 GB

## What the Script Does (Detailed)

### 1. System Check (2 minutes)
- Verifies macOS version
- Checks available RAM
- Checks free disk space
- Detects CPU architecture (Intel/Apple Silicon)

### 2. Install Homebrew (3-5 minutes)
- Downloads and installs if not present
- Configures PATH for Apple Silicon Macs
- Updates Homebrew

### 3. Install Node.js (3-5 minutes)
- Installs nvm (Node Version Manager)
- Installs Node.js 22.x
- Sets Node 22 as default
- Verifies npm installation

### 4. Install Docker Desktop (5-10 minutes)
- Downloads appropriate version (Intel/Apple Silicon)
- Installs Docker.app
- Waits for Docker to start
- Verifies Docker is running

### 5. Clone Repository (2-3 minutes)
- Clones from GitHub
- Sets up in `~/medplum`
- Handles existing directories

### 6. Start Docker Services (1 minute)
- Starts PostgreSQL
- Starts Redis
- Waits for services to be ready

### 7. Install Dependencies (10-20 minutes)
- Runs `npm ci`
- Downloads ~1,600 packages
- **This is memory intensive!**

### 8. Build Packages (5-15 minutes)
- Runs `npm run build:fast`
- Compiles TypeScript
- Builds API and App packages
- **Also memory intensive!**

### 9. Create Helper Scripts (< 1 minute)
- Creates start script
- Creates stop script
- Makes them executable

### 10. Start Medplum (Optional)
- Prompts to start immediately
- Or save for later

## Troubleshooting

### Script Fails During npm Install

**Problem**: Process killed or timeout

**Solution**:
1. Check available RAM: `vm_stat`
2. Close other applications
3. Rerun the script - it will resume
4. Or manually run:
   ```bash
   cd ~/medplum
   npm ci
   ```

### Docker Desktop Won't Start

**Problem**: Docker fails to launch

**Solution**:
1. Open Docker Desktop manually from Applications
2. Grant necessary permissions
3. Wait for whale icon to become steady
4. Press Enter in the script to continue

### Build Fails

**Problem**: `npm run build:fast` fails

**Solution**:
1. Ensure Node version is correct:
   ```bash
   node --version  # Should be v22.x.x
   ```
2. Rebuild:
   ```bash
   cd ~/medplum
   npm run build:fast
   ```

### Services Won't Start

**Problem**: start-medplum.sh doesn't work

**Solution**:
1. Check Docker is running:
   ```bash
   docker ps
   ```
2. Check logs:
   ```bash
   tail -f /tmp/medplum-api.log
   tail -f /tmp/medplum-app.log
   ```
3. Restart Docker:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

### Port Already in Use

**Problem**: Port 3000 or 8103 already in use

**Solution**:
```bash
# Find process using port
lsof -ti:3000
lsof -ti:8103

# Kill it
kill $(lsof -ti:3000)
kill $(lsof -ti:8103)
```

### Out of Memory During Build

**Problem**: System runs out of RAM

**Solution**:
1. **Close all other applications**
2. **Restart Mac** to free memory
3. Try building individual packages:
   ```bash
   cd ~/medplum/packages/core
   npm run build
   
   cd ../fhir-router
   npm run build
   
   cd ../server
   npm run build
   
   cd ../app
   npm run build
   ```

## Running on Different Macs

### Transfer to Another Mac

**Option 1: Run Script on New Mac**

Just copy the script and run it:
```bash
scp setup-medplum-local.sh othermac:~/
ssh othermac
./setup-medplum-local.sh
```

**Option 2: Share via USB/Network**

```bash
# On original Mac
cp setup-medplum-local.sh /path/to/usb/

# On new Mac
cp /path/to/usb/setup-medplum-local.sh ~/
./setup-medplum-local.sh
```

**Option 3: Download from GitHub**

```bash
curl -O https://raw.githubusercontent.com/.../setup-medplum-local.sh
chmod +x setup-medplum-local.sh
./setup-medplum-local.sh
```

### Portable Installation

The installation is **self-contained** in:
- `~/medplum` - All code and builds
- `~/.nvm` - Node.js installation
- Docker Desktop - System-wide
- Homebrew - System-wide

You **cannot** easily move it between Macs. Rerun the script instead.

## Uninstalling

### Remove Medplum

```bash
# Stop services
~/medplum/stop-medplum.sh

# Remove repository
rm -rf ~/medplum

# Stop Docker containers
docker-compose down
```

### Remove All Components

```bash
# Remove Medplum
rm -rf ~/medplum

# Remove nvm and Node
rm -rf ~/.nvm

# Uninstall Docker Desktop
# Go to Applications, delete Docker.app

# Uninstall Homebrew (optional)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
```

## System Resource Usage

### When Running

| Component | CPU | RAM | Notes |
|-----------|-----|-----|-------|
| Docker Desktop | ~10% | ~1 GB | Background |
| PostgreSQL | ~5% | ~200 MB | Via Docker |
| Redis | ~2% | ~50 MB | Via Docker |
| API Server | ~20% | ~500 MB | Node.js |
| Web App (dev) | ~30% | ~1 GB | Vite + HMR |
| **Total** | **~70%** | **~3 GB** | **Active development** |

### During Build

| Phase | Peak RAM |
|-------|----------|
| npm ci | ~4 GB |
| Build packages | ~6 GB |
| Database migrations | ~2 GB |

**Total System RAM Needed**: 16 GB minimum

## Comparison: This Script vs Manual Setup

| Task | Manual | Script | Time Saved |
|------|--------|--------|------------|
| Install Homebrew | 5 min | Auto | 5 min |
| Install Node via nvm | 10 min | Auto | 10 min |
| Install Docker | 10 min | Auto | 10 min |
| Clone repo | 3 min | Auto | - |
| Install deps | 20 min | Auto | - |
| Build packages | 15 min | Auto | - |
| Create scripts | 5 min | Auto | 5 min |
| Troubleshooting | 30 min+ | Minimal | 30+ min |
| **Total** | **90+ min** | **30-45 min** | **45+ min** |

## Benefits of Local Setup vs Cloud

### Pros (Local)
- ✅ No monthly costs
- ✅ Works offline (after setup)
- ✅ Full control
- ✅ Faster iteration (no network latency)
- ✅ Privacy (all data local)

### Cons (Local)
- ❌ Requires powerful Mac (16 GB+ RAM)
- ❌ Uses significant resources
- ❌ Battery drain on laptops
- ❌ Initial setup time
- ❌ Can't access from other devices

### When to Use Local vs Cloud

**Use Local Setup If**:
- You have 16 GB+ RAM
- Working on personal/company Mac
- Need offline capability
- Don't want monthly costs
- Short-term development

**Use Cloud Setup If**:
- Mac has < 16 GB RAM
- Want to develop from multiple devices
- Need consistent environment
- Okay with ~$40/month cost
- Team development

## Summary

✅ **One-click setup** - Single script does everything  
✅ **Smart detection** - Checks requirements, skips installed tools  
✅ **Fully automated** - No manual configuration needed  
✅ **Production-ready** - Complete development environment  
✅ **Helpful scripts** - Easy start/stop commands  
✅ **Works on any Mac** - Intel or Apple Silicon  
✅ **Time-saving** - 30-45 minutes vs 90+ minutes manual  

**Requirements**: 16 GB RAM minimum, 50 GB disk space

**Run it**: `./setup-medplum-local.sh`

**After setup**: `~/medplum/start-medplum.sh` and visit http://localhost:3000

---

**Questions?** The script has detailed progress messages and helpful error output to guide you through any issues.
