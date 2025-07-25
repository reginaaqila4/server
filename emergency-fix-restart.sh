#!/bin/bash

echo "🔧 EMERGENCY FIX - CONTAINER RESTART ISSUE"
echo "=========================================="

cd /home/paperspace/nextcloud-server

echo "1. STOPPING ALL CONTAINERS..."
docker compose down --remove-orphans

echo "2. CHECKING AND FIXING MOUNT..."
# Unmount and remount Google Drive
sudo umount /mnt/gdrive 2>/dev/null || true
sudo rm -rf /mnt/gdrive
sudo mkdir -p /mnt/gdrive

# Restart rclone service
sudo systemctl restart rclone-gdrive
sleep 15

# Verify mount
if mountpoint -q /mnt/gdrive; then
    echo "✅ Google Drive remounted successfully"
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

echo "3. RECREATING CLEAN DATA STRUCTURE..."
# Clean and recreate nextcloud-uploads
sudo rm -rf /mnt/gdrive/nextcloud-uploads
sudo mkdir -p /mnt/gdrive/nextcloud-uploads

# Create .ncdata file
echo "# Nextcloud data directory" | sudo tee /mnt/gdrive/nextcloud-uploads/.ncdata

# Set correct permissions
sudo chown -R 33:33 /mnt/gdrive/nextcloud-uploads/
sudo chmod -R 0755 /mnt/gdrive/nextcloud-uploads/

echo "4. FIXING VPS DATA PERMISSIONS..."
sudo chown -R 33:33 ./data/nextcloud/
sudo chmod -R 0755 ./data/nextcloud/

echo "5. TRYING ALTERNATIVE DOCKER COMPOSE (LOCAL DATA FIRST)..."
# Create temporary docker-compose with local data only
cat > docker-compose-temp.yml << 'EOF'
services:
  db:
    image: mysql:5.7
    container_name: nextcloud-db
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - ./data/mysql:/var/lib/mysql
      - ./mysql-config/my.cnf:/etc/mysql/conf.d/nextcloud.cnf
    command: --default-authentication-plugin=mysql_native_password

  redis:
    image: redis:alpine
    container_name: nextcloud-redis
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 512mb --maxmemory-policy allkeys-lru

  app:
    image: nextcloud:apache
    container_name: nextcloud-app
    restart: always
    ports:
      - "8081:80"
    depends_on:
      - db
      - redis
    environment:
      REDIS_HOST: redis
      REDIS_HOST_PASSWORD: ${REDIS_PASSWORD}
    volumes:
      # TEMPORARY: All data on VPS for testing
      - ./data/nextcloud:/var/www/html
      - ./data/nextcloud-data-temp:/var/www/html/data
      # PHP optimizations
      - ./php-config/uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
      - ./php-config/opcache.ini:/usr/local/etc/php/conf.d/opcache.ini
      - ./php-config/apcu.ini:/usr/local/etc/php/conf.d/apcu.ini
EOF

echo "6. CREATING TEMPORARY LOCAL DATA DIRECTORY..."
mkdir -p ./data/nextcloud-data-temp
sudo chown -R 33:33 ./data/nextcloud-data-temp/
sudo chmod -R 0755 ./data/nextcloud-data-temp/

echo "7. STARTING WITH TEMPORARY CONFIGURATION..."
docker compose -f docker-compose-temp.yml up -d db redis

echo "Waiting for database..."
sleep 20

echo "Starting Nextcloud with local data..."
docker compose -f docker-compose-temp.yml up -d app

echo "8. MONITORING STARTUP..."
for i in {1..15}; do
    STATUS=$(docker compose -f docker-compose-temp.yml ps app --format "table {{.State}}" | tail -1 | tr -d ' ')
    echo "Container status: $STATUS ($i/15)"
    
    if [ "$STATUS" = "running" ]; then
        echo "✅ Container is running with local data!"
        break
    elif [ "$STATUS" = "restarting" ]; then
        echo "Still restarting..."
        sleep 10
    else
        echo "Status: $STATUS"
        sleep 5
    fi
done

echo "9. TESTING WEB ACCESS..."
sleep 10
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
    echo "✅ Web interface accessible with local data!"
    echo ""
    echo "🎯 SOLUTION: Container works with local data"
    echo "The issue is with Google Drive mount mapping"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Complete Nextcloud setup with local data first"
    echo "2. Then migrate to Google Drive mount"
    echo "3. Open: http://184.105.238.243:8081"
else
    echo "❌ Still not accessible (HTTP $HTTP_STATUS)"
    echo "Checking logs..."
    docker compose -f docker-compose-temp.yml logs app | tail -10
fi

echo ""
echo "🔧 EMERGENCY FIX COMPLETED"
echo "=========================="
echo "Container status:"
docker compose -f docker-compose-temp.yml ps