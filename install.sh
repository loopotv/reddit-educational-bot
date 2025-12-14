#!/bin/bash

################################################################################
# Tutorial Bot - One-Click Installation Script
# 
# This script will:
# 1. Install Docker & Docker Compose
# 2. Setup directory structure
# 3. Configure environment
# 4. Start all services
#
# Usage: curl -fsSL https://your-url/install.sh | bash
# Or: wget -qO- https://your-url/install.sh | bash
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="/opt/tutorial-bot"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║           AI Tutorial Video Generator - Installer             ║"
    echo "║                   CTLT Method Automation                      ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}▶${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "Please run as root or with sudo"
        exit 1
    fi
}

check_os() {
    if [ ! -f /etc/os-release ]; then
        print_error "Cannot detect OS. This script supports Ubuntu/Debian only."
        exit 1
    fi
    
    . /etc/os-release
    if [[ ! "$ID" =~ ^(ubuntu|debian)$ ]]; then
        print_error "This script supports Ubuntu/Debian only. Detected: $ID"
        exit 1
    fi
    
    print_success "OS detected: $PRETTY_NAME"
}

################################################################################
# Installation Steps
################################################################################

install_dependencies() {
    print_step "Installing system dependencies..."
    
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq \
        curl \
        wget \
        git \
        ca-certificates \
        gnupg \
        lsb-release \
        jq \
        nano \
        > /dev/null 2>&1
    
    print_success "System dependencies installed"
}

install_docker() {
    if command -v docker &> /dev/null; then
        print_success "Docker already installed: $(docker --version)"
        return
    fi
    
    print_step "Installing Docker..."
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
    
    # Add user to docker group (if not root)
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER"
    fi
    
    systemctl enable docker > /dev/null 2>&1
    systemctl start docker
    
    print_success "Docker installed: $(docker --version)"
}

install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose already installed: $(docker-compose --version)"
        return
    fi
    
    print_step "Installing Docker Compose..."
    
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    print_success "Docker Compose installed: $(docker-compose --version)"
}

setup_directories() {
    print_step "Creating directory structure..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/shared"
    mkdir -p "$INSTALL_DIR/n8n-data"
    mkdir -p "$INSTALL_DIR/postgres-data"
    mkdir -p "$INSTALL_DIR/redis-data"
    
    # Set permissions
    chown -R 1000:1000 "$INSTALL_DIR/n8n-data"
    
    print_success "Directory structure created at $INSTALL_DIR"
}

download_files() {
    print_step "Downloading configuration files..."
    
    cd "$INSTALL_DIR"
    
    # Download docker-compose.yml
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: tutorial_n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - WEBHOOK_URL=http://${N8N_HOST}:5678/
      - GENERIC_TIMEZONE=Europe/Rome
    volumes:
      - ./n8n-data:/home/node/.n8n
      - ./shared:/shared
    networks:
      - tutorial_network

  postgres:
    image: postgres:15-alpine
    container_name: tutorial_postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=tutorial_bot
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
    networks:
      - tutorial_network

  redis:
    image: redis:7-alpine
    container_name: tutorial_redis
    restart: unless-stopped
    volumes:
      - ./redis-data:/data
    networks:
      - tutorial_network

networks:
  tutorial_network:
    driver: bridge
EOF
    
    print_success "docker-compose.yml created"
}

configure_environment() {
    print_step "Configuring environment variables..."
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
    
    cat > "$INSTALL_DIR/.env" << EOF
# Tutorial Bot Configuration
# Generated: $(date)

# N8N Configuration
N8N_USER=admin
N8N_PASSWORD=$(openssl rand -base64 12)
N8N_HOST=${SERVER_IP}

# Database
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=$(openssl rand -base64 16)

# API Keys - CONFIGURE THESE BEFORE STARTING
GROQ_API_KEY=your_groq_key_here
ANTHROPIC_API_KEY=your_claude_key_here
ELEVENLABS_API_KEY=your_elevenlabs_key_here
REPLICATE_API_KEY=your_replicate_key_here
SHOTSTACK_API_KEY=your_shotstack_key_here
SHOTSTACK_ENV=sandbox

# Optional APIs
RUNWAY_API_KEY=your_runway_key_here
PIKA_API_KEY=your_pika_key_here
EOF
    
    chmod 600 "$INSTALL_DIR/.env"
    
    print_success ".env file created with random passwords"
}

create_readme() {
    cat > "$INSTALL_DIR/NEXT_STEPS.txt" << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║               INSTALLATION COMPLETED ✓                         ║
╚═══════════════════════════════════════════════════════════════╝

📝 NEXT STEPS:

1. Configure API Keys
   cd /opt/tutorial-bot
   nano .env
   
   Required:
   - GROQ_API_KEY         (Free at console.groq.com)
   - SHOTSTACK_API_KEY    (Free sandbox at shotstack.io)
   - ELEVENLABS_API_KEY   (Trial at elevenlabs.io)
   - REPLICATE_API_KEY    (Credits at replicate.com)

2. Start Services
   docker-compose up -d

3. Access n8n
   Open browser: http://YOUR_SERVER_IP:5678
   Login credentials are in .env file

4. Import Workflow
   Download: https://github.com/your-repo/tutorial-bot/workflow.json
   n8n Menu → Import from File → Select workflow.json

5. Configure Credentials in n8n
   Each API node needs its credential configured

6. Test
   curl -X POST http://YOUR_SERVER_IP:5678/webhook/generate-tutorial \
     -H "Content-Type: application/json" \
     -d '{"topic": "portrait photography"}'

📚 DOCUMENTATION:
   - Full guide: /opt/tutorial-bot/README.md
   - Quick start: /opt/tutorial-bot/INSTALLATION.md
   - Examples: /opt/tutorial-bot/EXAMPLES.md
   - FAQ: /opt/tutorial-bot/FAQ.md

💡 USEFUL COMMANDS:
   Start:    cd /opt/tutorial-bot && docker-compose up -d
   Stop:     cd /opt/tutorial-bot && docker-compose down
   Logs:     cd /opt/tutorial-bot && docker-compose logs -f
   Restart:  cd /opt/tutorial-bot && docker-compose restart

🆘 SUPPORT:
   Email: alessandro@loopo.tv
   Docs: Check README.md and FAQ.md

EOF
    
    print_success "Next steps guide created"
}

display_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║              ✓ INSTALLATION COMPLETED SUCCESSFULLY            ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Read credentials
    source "$INSTALL_DIR/.env"
    
    echo -e "${BLUE}📍 Installation Directory:${NC} $INSTALL_DIR"
    echo ""
    echo -e "${BLUE}🔑 n8n Credentials:${NC}"
    echo "   Username: $N8N_USER"
    echo "   Password: $N8N_PASSWORD"
    echo ""
    echo -e "${BLUE}🌐 Access URL:${NC} http://$N8N_HOST:5678"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT - Before starting:${NC}"
    echo "   1. Configure API keys in .env"
    echo "   2. cd /opt/tutorial-bot && nano .env"
    echo "   3. docker-compose up -d"
    echo ""
    echo -e "${BLUE}📖 Read next steps:${NC} cat $INSTALL_DIR/NEXT_STEPS.txt"
    echo ""
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    print_header
    
    echo "This script will install Tutorial Bot on this server."
    echo "Installation directory: $INSTALL_DIR"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Installation cancelled"
        exit 0
    fi
    
    echo ""
    
    # Pre-flight checks
    check_root
    check_os
    
    # Install components
    install_dependencies
    install_docker
    install_docker_compose
    
    # Setup application
    setup_directories
    download_files
    configure_environment
    create_readme
    
    # Summary
    display_summary
    
    echo -e "${GREEN}✨ Installation complete!${NC}"
    echo ""
}

# Run installation
main
