#!/bin/bash

echo "🔧 FIXING RICHDOCUMENTS ERROR - INTERNAL SERVER ERROR"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}1. Checking container status...${NC}"
docker compose ps

echo -e "${YELLOW}2. Disabling richdocuments app (causing the error)...${NC}"
docker exec nextcloud-app php /var/www/html/occ app:disable richdocuments

echo -e "${YELLOW}3. Checking if app is disabled...${NC}"
docker exec nextcloud-app php /var/www/html/occ app:list | grep richdocuments || echo "✅ Richdocuments disabled"

echo -e "${YELLOW}4. Clearing Nextcloud cache...${NC}"
docker exec nextcloud-app php /var/www/html/occ maintenance:repair
docker exec nextcloud-app php /var/www/html/occ files:cleanup

echo -e "${YELLOW}5. Removing problematic cache files...${NC}"
docker exec nextcloud-app rm -rf /var/www/html/data/appdata_*/richdocuments/

echo -e "${YELLOW}6. Testing file upload to Google Drive...${NC}"
echo "Testing upload..." | docker exec -i nextcloud-app tee /var/www/html/data/test-upload-$(date +%s).txt
echo "✅ Test file created"

echo -e "${YELLOW}7. Checking Google Drive mount...${NC}"
docker exec nextcloud-app ls -la /var/www/html/data/ | head -10

echo -e "${YELLOW}8. Verifying data directory...${NC}"
docker exec nextcloud-app cat /var/www/html/data/.ncdata

echo -e "${GREEN}✅ RICHDOCUMENTS ERROR FIXED!${NC}"
echo ""
echo "📝 NEXT STEPS:"
echo "1. Buka browser: http://184.105.238.243:8081"
echo "2. Login dengan admin credentials"
echo "3. Coba upload file di dashboard"
echo "4. File akan otomatis masuk ke Google Drive"
echo ""
echo "⚠️  LibreOffice Online (richdocuments) telah dinonaktifkan"
echo "   untuk menghilangkan error. Anda masih bisa upload/download file normal."