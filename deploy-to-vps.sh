#!/bin/bash

################################################################################
# Tutorial Bot - VPS Deployment Script
# Integrates with existing n8n/postgres/ffmpeg setup on Contabo VPS
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║      Tutorial Bot - VPS Deployment (Wavespeed + FFmpeg)      ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Configuration
VPS_HOST="contabo"
REMOTE_DIR="/opt/tutorial-bot"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"

print_step "Step 1: Creating remote directory structure..."
ssh $VPS_HOST "sudo mkdir -p $REMOTE_DIR"
print_success "Directory created"

print_step "Step 2: Uploading docker-compose.yml..."
scp "$LOCAL_DIR/docker-compose.yml" $VPS_HOST:$REMOTE_DIR/
print_success "docker-compose.yml uploaded"

print_step "Step 3: Uploading workflow file..."
scp "$LOCAL_DIR/workflow-wavespeed-ffmpeg.json" $VPS_HOST:$REMOTE_DIR/workflow.json
print_success "Workflow uploaded"

print_step "Step 4: Uploading .env template..."
scp "$LOCAL_DIR/.env.template" $VPS_HOST:$REMOTE_DIR/
print_success ".env template uploaded"

print_step "Step 5: Checking if .env exists on VPS..."
if ssh $VPS_HOST "test -f $REMOTE_DIR/.env"; then
    print_warning ".env already exists, skipping creation"
else
    print_step "Creating .env file..."
    ssh $VPS_HOST "cp $REMOTE_DIR/.env.template $REMOTE_DIR/.env"
    print_warning "Please update $REMOTE_DIR/.env with your Wavespeed API key!"
fi

print_step "Step 6: Updating existing n8n .env with Wavespeed key..."
echo ""
echo -e "${YELLOW}IMPORTANT:${NC} You need to add your Wavespeed API key to /opt/n8n/.env"
echo ""
read -p "Do you want to add it now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter your Wavespeed API key: " WAVESPEED_KEY
    ssh $VPS_HOST "echo 'WAVESPEED_API_KEY=$WAVESPEED_KEY' | sudo tee -a /opt/n8n/.env > /dev/null"
    print_success "Wavespeed API key added to n8n .env"
fi

print_step "Step 7: Starting Redis container..."
ssh $VPS_HOST "cd $REMOTE_DIR && docker compose up -d"
print_success "Redis container started"

print_step "Step 8: Verifying containers..."
ssh $VPS_HOST "docker ps | grep -E '(n8n|postgres|ffmpeg|tutorial_redis)'"
echo ""

print_step "Step 9: Importing workflow into n8n..."
echo ""
echo -e "${BLUE}Manual steps required:${NC}"
echo "1. Open https://n8n.loopo.tv in your browser"
echo "2. Login with your credentials"
echo "3. Go to: Workflows → Import from File"
echo "4. Upload: $REMOTE_DIR/workflow.json"
echo "5. Configure Wavespeed API credential:"
echo "   - Credential Type: Header Auth"
echo "   - Name: Wavespeed API Key"
echo "   - Header Name: Authorization"
echo "   - Header Value: Bearer YOUR_WAVESPEED_API_KEY"
echo "6. Activate the workflow (toggle switch)"
echo ""

print_step "Step 10: Setting up nginx for video serving..."
echo ""
echo -e "${YELLOW}Add this to your nginx config:${NC}"
cat << 'EOF'

location /videos/ {
    alias /var/www/movies/;
    autoindex off;
    add_header Cache-Control "public, max-age=31536000";
}

location /images/ {
    alias /var/www/images/;
    autoindex off;
    add_header Cache-Control "public, max-age=31536000";
}

EOF
echo ""
read -p "Do you want to add this nginx config automatically? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ssh $VPS_HOST "sudo tee -a /etc/nginx/sites-available/n8n > /dev/null" << 'EOF'

location /videos/ {
    alias /var/www/movies/;
    autoindex off;
    add_header Cache-Control "public, max-age=31536000";
}

location /images/ {
    alias /var/www/images/;
    autoindex off;
    add_header Cache-Control "public, max-age=31536000";
}
EOF
    ssh $VPS_HOST "sudo nginx -t && sudo systemctl reload nginx"
    print_success "Nginx configuration updated"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║              ✓ DEPLOYMENT COMPLETED SUCCESSFULLY              ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo ""
echo "1. Import workflow in n8n web UI (see Step 9 above)"
echo "2. Test the webhook:"
echo ""
echo "   curl -X POST https://n8n.loopo.tv/webhook/generate-tutorial \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"topic\": \"portrait photography\", \"style\": \"cinematic editorial\", \"duration\": 30}'"
echo ""
echo "3. Monitor logs:"
echo "   ssh $VPS_HOST 'docker logs -f n8n'"
echo ""
echo -e "${BLUE}💰 Cost Estimate (per 45-second video):${NC}"
echo "   - Groq (script):     \$0 (free)"
echo "   - Wavespeed (audio): ~\$0.05 (MiniMax Speech-02 HD)"
echo "   - Wavespeed (images):~\$0.03 (FLUX-dev, 5-6 images)"
echo "   - FFmpeg rendering:  \$0 (local)"
echo "   - Total:            ~\$0.08 per video"
echo ""
echo -e "${GREEN}✨ Deployment complete!${NC}"
echo ""
