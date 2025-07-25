#!/bin/bash

echo "🔍 DEBUGGING NEXTCLOUD CONTAINER RESTART ISSUE"
echo "=============================================="

cd /home/paperspace/nextcloud-server

echo "1. Checking container status..."
docker compose ps

echo ""
echo "2. Checking nextcloud-app logs (last 50 lines)..."
docker compose logs app | tail -50

echo ""
echo "3. Checking Google Drive mount..."
mountpoint /mnt/gdrive && echo "✅ Google Drive mounted" || echo "❌ Google Drive not mounted"

echo ""
echo "4. Checking mount permissions..."
ls -ld /mnt/gdrive/nextcloud-uploads/ 2>/dev/null || echo "❌ nextcloud-uploads directory not found"

echo ""
echo "5. Checking if data directory is accessible..."
docker exec nextcloud-db echo "Database is running" 2>/dev/null || echo "❌ Database not accessible"

echo ""
echo "6. Checking for mount conflicts..."
df -h | grep gdrive

echo ""
echo "7. Checking systemd rclone service..."
sudo systemctl status rclone-gdrive | head -10

echo ""
echo "8. Testing manual container start..."
echo "Stopping current containers..."
docker compose down

echo "Starting only database and redis..."
docker compose up -d db redis

echo "Waiting 10 seconds..."
sleep 10

echo "Testing database connection..."
docker exec nextcloud-db mysql -u root -pNextcloudRoot123! -e "SHOW DATABASES;"

echo ""
echo "🎯 DIAGNOSIS COMPLETE - Check the logs above for errors"