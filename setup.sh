#!/bin/bash

# Tutorial Bot Setup Script
# Per VPS Contabo - Ubuntu

set -e

echo "🚀 Tutorial Bot - Setup Script"
echo "================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo "❌ Please run as root (sudo ./setup.sh)"
   exit 1
fi

# Update system
echo "📦 Updating system packages..."
apt-get update && apt-get upgrade -y

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $SUDO_USER
    rm get-docker.sh
else
    echo "✅ Docker already installed"
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "🐳 Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo "✅ Docker Compose already installed"
fi

# Create directories
echo "📁 Creating directory structure..."
mkdir -p /opt/tutorial-bot
mkdir -p /opt/tutorial-bot/shared
mkdir -p /opt/tutorial-bot/n8n-data
mkdir -p /opt/tutorial-bot/postgres-data
mkdir -p /opt/tutorial-bot/redis-data

# Copy files
echo "📋 Copying configuration files..."
cp docker-compose.yml /opt/tutorial-bot/
cp .env.template /opt/tutorial-bot/.env

echo ""
echo "⚙️  CONFIGURATION REQUIRED"
echo "================================"
echo ""
echo "1. Edit /opt/tutorial-bot/.env with your API keys:"
echo "   nano /opt/tutorial-bot/.env"
echo ""
echo "2. Update these values:"
echo "   - N8N_PASSWORD (secure password)"
echo "   - N8N_HOST (your domain, e.g., n8n.yourdomain.com)"
echo "   - POSTGRES_PASSWORD (secure password)"
echo "   - All API keys for services you'll use"
echo ""
echo "3. Start the stack:"
echo "   cd /opt/tutorial-bot"
echo "   docker-compose up -d"
echo ""
echo "4. Import workflow:"
echo "   - Open n8n at https://your-domain:5678"
echo "   - Go to Workflows → Import from File"
echo "   - Upload workflow.json"
echo ""
echo "5. Configure credentials in n8n:"
echo "   - Groq API"
echo "   - ElevenLabs API"
echo "   - Replicate API"
echo "   - Shotstack API"
echo ""

# Install Nginx (optional, for reverse proxy)
read -p "Install Nginx for reverse proxy? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🌐 Installing Nginx..."
    apt-get install -y nginx certbot python3-certbot-nginx
    
    # Create basic Nginx config
    cat > /etc/nginx/sites-available/n8n << 'EOF'
server {
    listen 80;
    server_name YOUR_DOMAIN_HERE;
    
    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
    
    echo ""
    echo "📝 Nginx config created at /etc/nginx/sites-available/n8n"
    echo "Update YOUR_DOMAIN_HERE with your actual domain"
    echo ""
    echo "Then run:"
    echo "  ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/"
    echo "  certbot --nginx -d your-domain.com"
    echo "  systemctl reload nginx"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure .env file"
echo "2. Start Docker containers"
echo "3. Import workflow in n8n"
echo "4. Test with: curl -X POST http://localhost:5678/webhook/generate-tutorial -H 'Content-Type: application/json' -d '{\"topic\": \"portrait photography\"}'"
echo ""
