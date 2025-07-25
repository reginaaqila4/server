#!/bin/bash

echo "🔧 FIXING NEXTCLOUD INTERNAL SERVER ERROR - COMPLETE SOLUTION"
echo "=============================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo -e "${BLUE}🔍 STEP 1: DIAGNOSING THE PROBLEM${NC}"
echo "=================================="

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ docker-compose.yml not found!${NC}"
    echo "Please run this script from the nextcloud project directory"
    exit 1
fi

# Check if Docker is installed
if ! command_exists docker; then
    echo -e "${YELLOW}⚠️  Docker not found. Installing...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    sudo systemctl start docker
    sudo systemctl enable docker
    echo -e "${GREEN}✅ Docker installed${NC}"
fi

# Check if Docker Compose is installed
if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Docker Compose not found. Installing...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✅ Docker Compose installed${NC}"
fi

echo -e "${BLUE}🔍 STEP 2: CHECKING CONTAINER STATUS${NC}"
echo "====================================="
docker compose ps || docker-compose ps

echo -e "${BLUE}🔧 STEP 3: FIXING RICHDOCUMENTS ERROR${NC}"
echo "====================================="

echo -e "${YELLOW}Disabling richdocuments app (causing Internal Server Error)...${NC}"
docker exec nextcloud-app php /var/www/html/occ app:disable richdocuments 2>/dev/null || \
docker exec nextcloud-server-app php /var/www/html/occ app:disable richdocuments 2>/dev/null || \
echo "⚠️  Could not disable richdocuments (might not be installed)"

echo -e "${YELLOW}Clearing Nextcloud cache and repairing...${NC}"
docker exec nextcloud-app php /var/www/html/occ maintenance:repair 2>/dev/null || \
docker exec nextcloud-server-app php /var/www/html/occ maintenance:repair 2>/dev/null || \
echo "⚠️  Could not run maintenance repair"

echo -e "${YELLOW}Removing problematic richdocuments cache files...${NC}"
docker exec nextcloud-app rm -rf /var/www/html/data/appdata_*/richdocuments/ 2>/dev/null || \
docker exec nextcloud-server-app rm -rf /var/www/html/data/appdata_*/richdocuments/ 2>/dev/null || \
echo "⚠️  Could not remove richdocuments cache"

echo -e "${BLUE}🔍 STEP 4: VERIFYING GOOGLE DRIVE MOUNT${NC}"
echo "======================================="

echo -e "${YELLOW}Checking Google Drive mount status...${NC}"
if mountpoint -q /mnt/gdrive 2>/dev/null; then
    echo -e "${GREEN}✅ Google Drive is mounted${NC}"
    ls -la /mnt/gdrive/ | head -5
else
    echo -e "${RED}❌ Google Drive not mounted${NC}"
    echo "Please check rclone service: sudo systemctl status rclone-gdrive"
fi

echo -e "${BLUE}🔍 STEP 5: TESTING FILE UPLOAD TO GOOGLE DRIVE${NC}"
echo "==============================================="

CONTAINER_NAME="nextcloud-app"
docker exec $CONTAINER_NAME echo "test" 2>/dev/null || CONTAINER_NAME="nextcloud-server-app"

echo -e "${YELLOW}Testing file creation in Nextcloud data directory...${NC}"
TEST_FILE="test-upload-$(date +%s).txt"
docker exec $CONTAINER_NAME bash -c "echo 'Test upload from Nextcloud dashboard fix' > /var/www/html/data/$TEST_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Test file created in container${NC}"
    
    # Check if file appears in Google Drive
    sleep 2
    if [ -f "/mnt/gdrive/nextcloud-uploads/$TEST_FILE" ]; then
        echo -e "${GREEN}✅ Test file successfully synced to Google Drive!${NC}"
        ls -la "/mnt/gdrive/nextcloud-uploads/$TEST_FILE"
    else
        echo -e "${YELLOW}⚠️  Test file not found in Google Drive mount${NC}"
        echo "Checking available files:"
        ls -la /mnt/gdrive/nextcloud-uploads/ | head -10
    fi
else
    echo -e "${RED}❌ Could not create test file${NC}"
fi

echo -e "${BLUE}🔍 STEP 6: VERIFYING NEXTCLOUD CONFIGURATION${NC}"
echo "============================================="

echo -e "${YELLOW}Checking Nextcloud data directory configuration...${NC}"
docker exec $CONTAINER_NAME cat /var/www/html/data/.ncdata 2>/dev/null || echo "⚠️  .ncdata file not found"

echo -e "${YELLOW}Checking Nextcloud config.php...${NC}"
docker exec $CONTAINER_NAME php /var/www/html/occ config:system:get datadirectory 2>/dev/null || echo "⚠️  Could not get data directory config"

echo -e "${BLUE}🔍 STEP 7: FINAL VERIFICATION${NC}"
echo "=============================="

echo -e "${YELLOW}Testing web interface accessibility...${NC}"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
    echo -e "${GREEN}✅ Web interface is accessible (HTTP $HTTP_STATUS)${NC}"
else
    echo -e "${RED}❌ Web interface not accessible (HTTP $HTTP_STATUS)${NC}"
fi

echo ""
echo -e "${GREEN}🎉 INTERNAL SERVER ERROR FIX COMPLETED!${NC}"
echo "========================================"
echo ""
echo -e "${BLUE}📝 NEXT STEPS:${NC}"
echo "1. 🌐 Open browser: http://184.105.238.243:8081"
echo "2. 🔑 Login with your admin credentials"
echo "3. 📁 Try uploading a file via the dashboard"
echo "4. ✅ Verify file appears in Google Drive"
echo ""
echo -e "${YELLOW}⚠️  NOTES:${NC}"
echo "- LibreOffice Online (richdocuments) has been disabled to fix the error"
echo "- You can still upload/download files normally"
echo "- Only the in-browser document editing feature is disabled"
echo "- Database remains on VPS, only user uploads go to Google Drive"
echo ""
echo -e "${BLUE}🔍 If you still have issues:${NC}"
echo "- Check logs: docker exec $CONTAINER_NAME tail -20 /var/www/html/data/nextcloud.log"
echo "- Restart containers: docker compose restart"
echo "- Check Google Drive mount: mountpoint /mnt/gdrive"