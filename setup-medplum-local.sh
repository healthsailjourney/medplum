#!/bin/bash

################################################################################
# Medplum Local Development Setup - One-Click Installation
#
# This script automatically sets up Medplum development environment on any Mac
# with sufficient resources (16 GB RAM minimum recommended).
#
# What it does:
# 1. Checks system requirements (RAM, disk space)
# 2. Installs Homebrew (if needed)
# 3. Installs Node.js 22.x via nvm
# 4. Installs Docker Desktop
# 5. Clones Medplum repository
# 6. Installs dependencies
# 7. Builds packages
# 8. Starts Docker services
# 9. Starts Medplum server and app
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/.../setup-medplum-local.sh | bash
#   OR
#   ./setup-medplum-local.sh
#
# Requirements:
# - macOS (Big Sur 11.0 or later)
# - 16 GB RAM minimum (32 GB recommended)
# - 50 GB free disk space
# - Admin privileges (for Docker installation)
#
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
MEDPLUM_DIR="$HOME/medplum"
MIN_RAM_GB=12  # Minimum recommended (will warn if less than 16)
MIN_DISK_GB=50
NODE_VERSION="22"
NVM_VERSION="0.40.0"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_step() {
    echo -e "${MAGENTA}➜ $1${NC}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

prompt_yes_no() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

get_total_ram_gb() {
    local ram_bytes=$(sysctl -n hw.memsize)
    echo $((ram_bytes / 1024 / 1024 / 1024))
}

get_free_disk_gb() {
    local free_kb=$(df -k "$HOME" | tail -1 | awk '{print $4}')
    echo $((free_kb / 1024 / 1024))
}

################################################################################
# Welcome Screen
################################################################################

clear
print_header "Medplum Local Development Environment Setup"

cat << "EOF"
    __  ___          __      __
   /  |/  /__  ____/ /___  / /_  ______ ___
  / /|_/ / _ \/ __  / __ \/ / / / / __ `__ \
 / /  / /  __/ /_/ / /_/ / / /_/ / / / / / /
/_/  /_/\___/\__,_/ .___/_/\__,_/_/ /_/ /_/
                 /_/
           Local Development Setup

EOF

echo "This script will set up a complete Medplum development environment"
echo "on this Mac, including:"
echo ""
echo "  ✓ Homebrew package manager"
echo "  ✓ Node.js 22.x (via nvm)"
echo "  ✓ Docker Desktop"
echo "  ✓ PostgreSQL & Redis (via Docker)"
echo "  ✓ Medplum repository"
echo "  ✓ All dependencies and built packages"
echo ""
echo "Estimated time: 30-45 minutes"
echo ""

if ! prompt_yes_no "Continue with setup?"; then
    echo "Setup cancelled."
    exit 0
fi

################################################################################
# System Requirements Check
################################################################################

print_header "Checking System Requirements"

# Check macOS version
OS_VERSION=$(sw_vers -productVersion)
print_info "macOS version: $OS_VERSION"

# Check RAM
TOTAL_RAM=$(get_total_ram_gb)
print_info "Total RAM: ${TOTAL_RAM} GB"

if [ "$TOTAL_RAM" -lt "$MIN_RAM_GB" ]; then
    print_error "Insufficient RAM: ${TOTAL_RAM} GB (minimum ${MIN_RAM_GB} GB)"
    echo ""
    echo "Medplum requires at least 16 GB RAM for optimal performance."
    echo "Your system has only ${TOTAL_RAM} GB."
    echo ""
    if ! prompt_yes_no "Continue anyway? (May experience issues)"; then
        exit 1
    fi
    print_warning "Proceeding with ${TOTAL_RAM} GB RAM (not recommended)"
elif [ "$TOTAL_RAM" -lt 16 ]; then
    print_warning "RAM: ${TOTAL_RAM} GB (16 GB recommended for best performance)"
else
    print_success "RAM: ${TOTAL_RAM} GB (sufficient)"
fi

# Check disk space
FREE_DISK=$(get_free_disk_gb)
print_info "Free disk space: ${FREE_DISK} GB"

if [ "$FREE_DISK" -lt "$MIN_DISK_GB" ]; then
    print_error "Insufficient disk space: ${FREE_DISK} GB (minimum ${MIN_DISK_GB} GB required)"
    exit 1
else
    print_success "Disk space: ${FREE_DISK} GB (sufficient)"
fi

# Check architecture
ARCH=$(uname -m)
print_info "Architecture: $ARCH"

################################################################################
# Step 1: Install Homebrew
################################################################################

print_header "Step 1: Homebrew Installation"

if command_exists brew; then
    print_success "Homebrew already installed: $(brew --version | head -n1)"
else
    print_step "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon
    if [[ "$ARCH" == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    print_success "Homebrew installed successfully"
fi

# Update Homebrew
print_step "Updating Homebrew..."
brew update > /dev/null 2>&1
print_success "Homebrew updated"

################################################################################
# Step 2: Install Node.js via nvm
################################################################################

print_header "Step 2: Node.js Installation"

if [ -d "$HOME/.nvm" ]; then
    print_success "nvm already installed"
else
    print_step "Installing nvm..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash
    print_success "nvm installed"
fi

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js 22
if nvm ls "$NODE_VERSION" > /dev/null 2>&1; then
    print_success "Node.js $NODE_VERSION already installed"
else
    print_step "Installing Node.js $NODE_VERSION..."
    nvm install "$NODE_VERSION"
    print_success "Node.js $NODE_VERSION installed"
fi

nvm use "$NODE_VERSION"
nvm alias default "$NODE_VERSION"

NODE_INSTALLED_VERSION=$(node --version)
NPM_INSTALLED_VERSION=$(npm --version)
print_success "Node.js: $NODE_INSTALLED_VERSION"
print_success "npm: $NPM_INSTALLED_VERSION"

################################################################################
# Step 3: Install Docker Desktop
################################################################################

print_header "Step 3: Docker Desktop Installation"

if command_exists docker; then
    print_success "Docker already installed: $(docker --version)"

    # Check if Docker is running
    if docker info > /dev/null 2>&1; then
        print_success "Docker is running"
    else
        print_warning "Docker is installed but not running"
        echo "Please start Docker Desktop manually and press Enter to continue..."
        read
    fi
else
    print_step "Docker not found. Installing Docker Desktop..."

    if [[ "$ARCH" == "arm64" ]]; then
        DOCKER_DMG_URL="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
    else
        DOCKER_DMG_URL="https://desktop.docker.com/mac/main/amd64/Docker.dmg"
    fi

    print_info "Downloading Docker Desktop..."
    curl -L "$DOCKER_DMG_URL" -o /tmp/Docker.dmg

    print_info "Mounting Docker.dmg..."
    hdiutil attach /tmp/Docker.dmg -nobrowse

    print_info "Installing Docker Desktop..."
    cp -R /Volumes/Docker/Docker.app /Applications/

    print_info "Unmounting Docker.dmg..."
    hdiutil detach /Volumes/Docker
    rm /tmp/Docker.dmg

    print_success "Docker Desktop installed"

    echo ""
    print_warning "Please start Docker Desktop from Applications and grant necessary permissions."
    echo "Press Enter after Docker Desktop is running..."
    read

    # Open Docker Desktop
    open -a Docker

    echo "Waiting for Docker to start..."
    for i in {1..60}; do
        if docker info > /dev/null 2>&1; then
            print_success "Docker is running"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""

    if ! docker info > /dev/null 2>&1; then
        print_error "Docker failed to start. Please start Docker Desktop manually."
        exit 1
    fi
fi

################################################################################
# Step 4: Install Git (if needed)
################################################################################

print_header "Step 4: Git Installation"

if command_exists git; then
    print_success "Git already installed: $(git --version)"
else
    print_step "Installing Git..."
    brew install git
    print_success "Git installed"
fi

################################################################################
# Step 5: Clone Medplum Repository
################################################################################

print_header "Step 5: Cloning Medplum Repository"

if [ -d "$MEDPLUM_DIR" ]; then
    print_warning "Directory already exists: $MEDPLUM_DIR"
    if prompt_yes_no "Delete and re-clone?"; then
        rm -rf "$MEDPLUM_DIR"
        print_step "Cloning Medplum repository..."
        git clone https://github.com/medplum/medplum.git "$MEDPLUM_DIR"
        print_success "Repository cloned"
    else
        print_info "Using existing directory"
    fi
else
    print_step "Cloning Medplum repository to $MEDPLUM_DIR..."
    git clone https://github.com/medplum/medplum.git "$MEDPLUM_DIR"
    print_success "Repository cloned"
fi

cd "$MEDPLUM_DIR"

################################################################################
# Step 6: Start Docker Services
################################################################################

print_header "Step 6: Starting Docker Services (PostgreSQL & Redis)"

print_step "Starting Docker Compose services..."
docker-compose up -d

# Wait for services to be ready
print_info "Waiting for PostgreSQL to be ready..."
sleep 10

if docker-compose ps | grep -q "Up"; then
    print_success "Docker services running:"
    docker-compose ps
else
    print_error "Failed to start Docker services"
    exit 1
fi

################################################################################
# Step 7: Install Dependencies
################################################################################

print_header "Step 7: Installing Dependencies"

print_warning "This step takes 10-20 minutes depending on your internet connection..."
print_step "Running npm ci..."

# Ensure nvm is loaded
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use "$NODE_VERSION"

# Install with progress indicator
npm ci 2>&1 | while read line; do
    echo "$line"
done

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    print_success "Dependencies installed successfully"
else
    print_error "Failed to install dependencies"
    exit 1
fi

################################################################################
# Step 8: Build Packages
################################################################################

print_header "Step 8: Building Packages"

print_warning "This step takes 5-15 minutes..."
print_step "Running npm run build:fast..."

npm run build:fast

if [ $? -eq 0 ]; then
    print_success "Packages built successfully"
else
    print_error "Failed to build packages"
    exit 1
fi

################################################################################
# Step 9: Create Helper Scripts
################################################################################

print_header "Step 9: Creating Helper Scripts"

# Create start script
cat > "$MEDPLUM_DIR/start-medplum.sh" <<'STARTSCRIPT'
#!/bin/bash
cd "$(dirname "$0")"

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 22

echo "Starting Docker services..."
docker-compose up -d

echo "Starting Medplum API server..."
cd packages/server
npm run dev > /tmp/medplum-api.log 2>&1 &
echo $! > /tmp/medplum-api.pid
echo "API server started (PID: $(cat /tmp/medplum-api.pid))"

echo "Starting Medplum web app..."
cd ../app
npm run dev > /tmp/medplum-app.log 2>&1 &
echo $! > /tmp/medplum-app.pid
echo "Web app started (PID: $(cat /tmp/medplum-app.pid))"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Medplum is starting!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Wait 2-3 minutes for services to fully start, then access:"
echo ""
echo "  Web App:  http://localhost:3000"
echo "  API:      http://localhost:8103/healthcheck"
echo ""
echo "  Login:    admin@example.com"
echo "  Password: medplum_admin"
echo ""
echo "Logs:"
echo "  API:  tail -f /tmp/medplum-api.log"
echo "  App:  tail -f /tmp/medplum-app.log"
echo ""
STARTSCRIPT

chmod +x "$MEDPLUM_DIR/start-medplum.sh"

# Create stop script
cat > "$MEDPLUM_DIR/stop-medplum.sh" <<'STOPSCRIPT'
#!/bin/bash
echo "Stopping Medplum services..."

if [ -f /tmp/medplum-api.pid ]; then
    kill $(cat /tmp/medplum-api.pid) 2>/dev/null
    rm /tmp/medplum-api.pid
    echo "API server stopped"
fi

if [ -f /tmp/medplum-app.pid ]; then
    kill $(cat /tmp/medplum-app.pid) 2>/dev/null
    rm /tmp/medplum-app.pid
    echo "Web app stopped"
fi

echo "Stopping Docker services..."
cd "$(dirname "$0")"
docker-compose down

echo "All services stopped"
STOPSCRIPT

chmod +x "$MEDPLUM_DIR/stop-medplum.sh"

print_success "Helper scripts created:"
print_info "  - $MEDPLUM_DIR/start-medplum.sh"
print_info "  - $MEDPLUM_DIR/stop-medplum.sh"

################################################################################
# Step 10: Start Medplum
################################################################################

print_header "Step 10: Starting Medplum"

if prompt_yes_no "Start Medplum now?"; then
    "$MEDPLUM_DIR/start-medplum.sh"
else
    print_info "You can start Medplum later with: $MEDPLUM_DIR/start-medplum.sh"
fi

################################################################################
# Setup Complete
################################################################################

print_header "🎉 Setup Complete!"

cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Medplum Development Environment Ready!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Installation Directory:
   $MEDPLUM_DIR

🚀 Quick Start Commands:

   Start Medplum:
   $MEDPLUM_DIR/start-medplum.sh

   Stop Medplum:
   $MEDPLUM_DIR/stop-medplum.sh

🌐 Access URLs (after starting):

   Web App:       http://localhost:3000
   API:           http://localhost:8103
   Health Check:  http://localhost:8103/healthcheck

🔐 Default Login:

   Email:    admin@example.com
   Password: medplum_admin

📊 Monitor Logs:

   API Server:  tail -f /tmp/medplum-api.log
   Web App:     tail -f /tmp/medplum-app.log

🐳 Docker Services:

   Status:  docker-compose ps
   Logs:    docker-compose logs -f

💡 Tips:

   • Wait 2-3 minutes after starting for services to fully initialize
   • Keep Docker Desktop running while developing
   • Use start/stop scripts to manage services
   • Monitor system resources with Activity Monitor

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Happy coding! 🚀

EOF

print_success "Setup completed successfully!"
