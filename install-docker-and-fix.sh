#!/bin/bash

echo "🚀 INSTALLING DOCKER & FIXING NEXTCLOUD ERROR"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}1. Installing Docker...${NC}"
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

echo -e "${YELLOW}2. Installing Docker Compose...${NC}"
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo -e "${YELLOW}3. Starting Docker service...${NC}"
sudo systemctl start docker
sudo systemctl enable docker

echo -e "${YELLOW}4. Checking Docker installation...${NC}"
docker --version
docker-compose --version

echo -e "${GREEN}✅ Docker installed successfully!${NC}"
echo ""
echo "⚠️  IMPORTANT: Anda perlu logout dan login kembali untuk menggunakan Docker tanpa sudo"
echo "   Atau jalankan: newgrp docker"
echo ""
echo "📝 NEXT: Jalankan script perbaikan richdocuments:"
echo "   chmod +x fix-richdocuments-error.sh"
echo "   ./fix-richdocuments-error.sh"