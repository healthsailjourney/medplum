#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install essential packages
apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    vim \
    htop \
    ca-certificates \
    gnupg \
    lsb-release

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Node.js 22.x using nvm for ubuntu user
sudo -u ubuntu bash <<'EOF'
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 22
nvm use 22
nvm alias default 22
EOF

# Install code-server (VS Code in browser)
curl -fsSL https://code-server.dev/install.sh | sh
systemctl enable code-server@ubuntu
systemctl start code-server@ubuntu

# Configure code-server
sudo -u ubuntu bash <<'EOF'
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml <<'YAML'
bind-addr: 0.0.0.0:8080
auth: password
password: medplum-dev-2024
cert: false
YAML
EOF

systemctl restart code-server@ubuntu

# Clone Medplum repository
sudo -u ubuntu bash <<'EOF'
cd /home/ubuntu
git clone ${github_repo} medplum
cd medplum

# Install dependencies (will be done manually or via startup script)
# This is commented out to avoid timeouts during instance creation
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# npm ci
# npm run build:fast

# Start Docker services
docker-compose up -d
EOF

# Create startup script for Medplum
cat > /home/ubuntu/start-medplum.sh <<'SCRIPT'
#!/bin/bash
cd /home/ubuntu/medplum
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Ensure Docker services are running
docker-compose up -d

# Start API server in background
cd packages/server
npm run dev > /tmp/medplum-api.log 2>&1 &
echo $! > /tmp/medplum-api.pid

# Start web app in background
cd ../app
npm run dev > /tmp/medplum-app.log 2>&1 &
echo $! > /tmp/medplum-app.pid

echo "Medplum services started!"
echo "API logs: tail -f /tmp/medplum-api.log"
echo "App logs: tail -f /tmp/medplum-app.log"
SCRIPT

chmod +x /home/ubuntu/start-medplum.sh
chown ubuntu:ubuntu /home/ubuntu/start-medplum.sh

# Create stop script
cat > /home/ubuntu/stop-medplum.sh <<'SCRIPT'
#!/bin/bash
if [ -f /tmp/medplum-api.pid ]; then
    kill $(cat /tmp/medplum-api.pid) 2>/dev/null
    rm /tmp/medplum-api.pid
fi

if [ -f /tmp/medplum-app.pid ]; then
    kill $(cat /tmp/medplum-app.pid) 2>/dev/null
    rm /tmp/medplum-app.pid
fi

echo "Medplum services stopped!"
SCRIPT

chmod +x /home/ubuntu/stop-medplum.sh
chown ubuntu:ubuntu /home/ubuntu/stop-medplum.sh

# Create README for the instance
cat > /home/ubuntu/README.md <<'README'
# Medplum Development Instance

This instance is pre-configured for Medplum development.

## Access Methods

1. **SSH**: Use the SSH command from Terraform outputs
2. **VS Code Server**: Access via browser at http://<instance-ip>:8080
   - Password: medplum-dev-2024

## Quick Start

```bash
# Install dependencies (first time only)
cd ~/medplum
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
npm ci
npm run build:fast

# Start Medplum services
./start-medplum.sh

# Stop Medplum services
./stop-medplum.sh
```

## Service URLs

- **API Server**: http://<instance-ip>:8103
- **Web App**: http://<instance-ip>:3000
- **Healthcheck**: http://<instance-ip>:8103/healthcheck

## Default Credentials

- **Email**: admin@example.com
- **Password**: medplum_admin

## Logs

- API logs: `tail -f /tmp/medplum-api.log`
- App logs: `tail -f /tmp/medplum-app.log`

## Docker Services

PostgreSQL and Redis are running via Docker Compose:
```bash
docker-compose ps
docker-compose logs -f
```

## System Resources

This instance has:
- 4 vCPUs
- 16 GB RAM
- 100 GB SSD

## Tips

- Use VS Code Server for browser-based development
- Or use SSH with VS Code Remote Development extension
- Monitor resources: `htop`
- Check Docker: `docker stats`
README

chown ubuntu:ubuntu /home/ubuntu/README.md

# Set up automatic security updates
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Log completion
echo "User data script completed at $(date)" > /var/log/user-data-complete.log
