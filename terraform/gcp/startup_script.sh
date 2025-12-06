#!/bin/bash
# This script is identical to the AWS user_data.sh
# Using the same setup process for consistency

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

# Install Node.js 22.x using nvm
sudo -u ubuntu bash <<'EOF'
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 22
nvm use 22
nvm alias default 22
EOF

# Install code-server
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

# Start Docker services
docker-compose up -d
EOF

# Create startup script
cat > /home/ubuntu/start-medplum.sh <<'SCRIPT'
#!/bin/bash
cd /home/ubuntu/medplum
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

docker-compose up -d

cd packages/server
npm run dev > /tmp/medplum-api.log 2>&1 &
echo $! > /tmp/medplum-api.pid

cd ../app
npm run dev > /tmp/medplum-app.log 2>&1 &
echo $! > /tmp/medplum-app.pid

echo "Medplum services started!"
SCRIPT

chmod +x /home/ubuntu/start-medplum.sh
chown ubuntu:ubuntu /home/ubuntu/start-medplum.sh

# Create stop script
cat > /home/ubuntu/stop-medplum.sh <<'SCRIPT'
#!/bin/bash
[ -f /tmp/medplum-api.pid ] && kill $(cat /tmp/medplum-api.pid) 2>/dev/null && rm /tmp/medplum-api.pid
[ -f /tmp/medplum-app.pid ] && kill $(cat /tmp/medplum-app.pid) 2>/dev/null && rm /tmp/medplum-app.pid
echo "Medplum services stopped!"
SCRIPT

chmod +x /home/ubuntu/stop-medplum.sh
chown ubuntu:ubuntu /home/ubuntu/stop-medplum.sh

# Create README
cat > /home/ubuntu/README.md <<'README'
# Medplum Development Instance (GCP)

See AWS README for complete documentation.

## GCP-Specific Commands

```bash
# Stop instance
gcloud compute instances stop medplum-dev-instance --zone=us-central1-a

# Start instance
gcloud compute instances start medplum-dev-instance --zone=us-central1-a

# SSH
gcloud compute ssh medplum-dev-instance --zone=us-central1-a
```
README

chown ubuntu:ubuntu /home/ubuntu/README.md

echo "Startup script completed at $(date)" > /var/log/startup-complete.log
