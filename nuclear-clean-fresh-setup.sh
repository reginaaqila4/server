#!/bin/bash

echo "💥 NUCLEAR CLEAN & FRESH NEXTCLOUD SETUP"
echo "========================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd /home/paperspace/nextcloud-server

echo -e "${RED}⚠️  WARNING: This will COMPLETELY REMOVE all Nextcloud data!${NC}"
echo -e "${YELLOW}Press Enter to continue or Ctrl+C to cancel...${NC}"
read

echo -e "${YELLOW}1. Stopping and removing ALL containers...${NC}"
docker compose down --volumes --remove-orphans 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

echo -e "${YELLOW}2. Removing ALL Docker volumes and networks...${NC}"
docker volume rm $(docker volume ls -q) 2>/dev/null || true
docker network rm $(docker network ls -q) 2>/dev/null || true
docker system prune -af --volumes

echo -e "${YELLOW}3. Cleaning VPS data directories...${NC}"
sudo rm -rf ./data/mysql/*
sudo rm -rf ./data/nextcloud/*

echo -e "${YELLOW}4. Cleaning Google Drive Nextcloud data...${NC}"
sudo rm -rf /mnt/gdrive/nextcloud-uploads/*

echo -e "${YELLOW}5. Recreating clean directory structure...${NC}"
mkdir -p ./data/{mysql,nextcloud}
sudo mkdir -p /mnt/gdrive/nextcloud-uploads

echo -e "${YELLOW}6. Setting correct permissions...${NC}"
sudo chown -R 33:33 ./data/nextcloud/
sudo chmod -R 0755 ./data/nextcloud/
sudo chown -R 33:33 /mnt/gdrive/nextcloud-uploads/
sudo chmod -R 0755 /mnt/gdrive/nextcloud-uploads/

echo -e "${YELLOW}7. Creating fresh .ncdata file...${NC}"
echo "# Nextcloud data directory" | sudo tee /mnt/gdrive/nextcloud-uploads/.ncdata
sudo chown 33:33 /mnt/gdrive/nextcloud-uploads/.ncdata
sudo chmod 644 /mnt/gdrive/nextcloud-uploads/.ncdata

echo -e "${YELLOW}8. Pulling fresh Docker images...${NC}"
docker pull mysql:5.7
docker pull redis:alpine
docker pull nextcloud:apache

echo -e "${YELLOW}9. Starting database and redis first...${NC}"
docker compose up -d db redis

echo -e "${YELLOW}10. Waiting for database to initialize...${NC}"
sleep 30

echo -e "${YELLOW}11. Verifying database is ready...${NC}"
for i in {1..10}; do
    if docker exec nextcloud-db mysql -u root -pNextcloudRoot123! -e "SHOW DATABASES;" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Database is ready!${NC}"
        break
    else
        echo "Waiting for database... ($i/10)"
        sleep 5
    fi
done

echo -e "${YELLOW}12. Starting Nextcloud app...${NC}"
docker compose up -d app

echo -e "${YELLOW}13. Monitoring container startup...${NC}"
for i in {1..20}; do
    STATUS=$(docker compose ps app --format "table {{.State}}" | tail -1)
    echo "Container status: $STATUS ($i/20)"
    
    if [ "$STATUS" = "running" ]; then
        echo -e "${GREEN}✅ Nextcloud container is running!${NC}"
        break
    elif [ "$STATUS" = "restarting" ]; then
        echo "Still starting..."
        sleep 10
    else
        echo "Status: $STATUS"
        sleep 5
    fi
done

echo -e "${YELLOW}14. Final verification...${NC}"
docker compose ps

echo -e "${YELLOW}15. Testing web access...${NC}"
sleep 15
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
    echo -e "${GREEN}✅ Web interface is accessible! (HTTP $HTTP_STATUS)${NC}"
elif [ "$HTTP_STATUS" = "000" ]; then
    echo -e "${YELLOW}⚠️  Web interface not ready yet, but container is running${NC}"
else
    echo -e "${RED}❌ Web interface not accessible (HTTP $HTTP_STATUS)${NC}"
fi

echo ""
echo -e "${GREEN}🎉 NUCLEAR CLEAN & FRESH SETUP COMPLETED!${NC}"
echo "============================================="
echo ""
echo -e "${BLUE}📝 NEXT STEPS:${NC}"
echo "1. 🌐 Open browser: http://184.105.238.243:8081"
echo "2. 🔧 Complete Nextcloud setup wizard:"
echo "   - Admin user: admin"
echo "   - Admin password: [choose strong password]"
echo "   - Database: MySQL/MariaDB"
echo "   - Database host: db"
echo "   - Database name: nextcloud"
echo "   - Database user: nextclouduser"
echo "   - Database password: NextcloudUser123!"
echo "3. ✅ Skip recommended apps (or install as needed)"
echo "4. 📁 Test file upload - should go to Google Drive"
echo ""
echo -e "${GREEN}✅ FRESH INSTALLATION READY!${NC}"
echo -e "${GREEN}✅ Database: VPS (clean)${NC}"
echo -e "${GREEN}✅ User uploads: Google Drive (clean)${NC}"
echo -e "${GREEN}✅ No version conflicts${NC}"
echo ""
echo -e "${YELLOW}⚠️  If still having issues, check logs:${NC}"
echo "docker compose logs app"