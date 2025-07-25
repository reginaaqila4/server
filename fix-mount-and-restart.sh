#!/bin/bash

echo "🔧 FIXING MOUNT ISSUE & CONTAINER RESTART"
echo "========================================="

cd /home/paperspace/nextcloud-server

echo "1. Stopping all containers..."
docker compose down

echo "2. Checking and fixing Google Drive mount..."
# Unmount if already mounted
sudo umount /mnt/gdrive 2>/dev/null || true

# Remove and recreate mount point
sudo rm -rf /mnt/gdrive
sudo mkdir -p /mnt/gdrive

echo "3. Restarting rclone service..."
sudo systemctl stop rclone-gdrive
sudo systemctl start rclone-gdrive

echo "4. Waiting for mount..."
sleep 15

echo "5. Verifying mount..."
if mountpoint -q /mnt/gdrive; then
    echo "✅ Google Drive mounted successfully"
else
    echo "❌ Mount failed, trying manual mount..."
    sudo /usr/bin/rclone mount alldrive: /mnt/gdrive \
        --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \
        --allow-other --allow-non-empty \
        --uid=33 --gid=33 --umask=007 \
        --vfs-cache-mode=full \
        --daemon
    sleep 10
fi

echo "6. Creating and fixing nextcloud-uploads directory..."
sudo mkdir -p /mnt/gdrive/nextcloud-uploads
sudo chown -R 33:33 /mnt/gdrive/nextcloud-uploads/
sudo chmod -R 0755 /mnt/gdrive/nextcloud-uploads/

# Create .ncdata file if not exists
if [ ! -f "/mnt/gdrive/nextcloud-uploads/.ncdata" ]; then
    echo "# Nextcloud data directory" | sudo tee /mnt/gdrive/nextcloud-uploads/.ncdata
    sudo chown 33:33 /mnt/gdrive/nextcloud-uploads/.ncdata
fi

echo "7. Fixing VPS data permissions..."
sudo chown -R 33:33 ./data/nextcloud/
sudo chmod -R 0755 ./data/nextcloud/

echo "8. Starting containers step by step..."
echo "Starting database and redis..."
docker compose up -d db redis

echo "Waiting for database..."
sleep 20

echo "Testing database..."
docker exec nextcloud-db mysql -u root -pNextcloudRoot123! -e "SHOW DATABASES;" || echo "Database not ready yet"

echo "9. Starting Nextcloud app..."
docker compose up -d app

echo "10. Waiting and monitoring..."
for i in {1..30}; do
    echo "Checking attempt $i/30..."
    STATUS=$(docker compose ps app --format "table {{.State}}" | tail -1)
    if [ "$STATUS" = "running" ]; then
        echo "✅ Container is running!"
        break
    elif [ "$STATUS" = "restarting" ]; then
        echo "⚠️  Still restarting... ($i/30)"
        sleep 5
    else
        echo "❌ Container status: $STATUS"
        sleep 5
    fi
done

echo "11. Final status check..."
docker compose ps

echo "12. Testing web access..."
sleep 10
curl -I http://localhost:8081 2>/dev/null || echo "Web interface not ready yet"

echo ""
echo "🎯 MOUNT & RESTART FIX COMPLETED"
echo "================================"
echo "If container still restarting, check logs with:"
echo "docker compose logs app"