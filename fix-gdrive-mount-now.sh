#!/bin/bash

echo "🔧 FIX GOOGLE DRIVE MOUNT - IMMEDIATE"
echo "===================================="
echo ""

# Check current docker-compose.yml
echo "📋 Current docker-compose.yml volumes:"
grep -A 10 "volumes:" docker-compose.yml | grep -E "(data|config)"

echo ""
echo "❌ Problem: docker-compose.yml masih menggunakan local storage"
echo "✅ Solution: Update untuk mount Google Drive"
echo ""

# Stop containers first
echo "🛑 Stopping containers..."
docker compose down

# Update docker-compose.yml with Google Drive mount
echo "📝 Updating docker-compose.yml..."
cat > docker-compose.yml << 'DOCKER_EOF'
services:
  db:
    image: mysql:8.0.36-debian
    container_name: nextcloud-server-db
    restart: always
    command: --default-authentication-plugin=mysql_native_password --innodb-buffer-pool-size=512M
    volumes:
      - nextcloud_db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=Nextcloud123!
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextclouduser
      - MYSQL_PASSWORD=Nextcloud123!

  redis:
    image: redis:alpine
    container_name: nextcloud-server-redis
    restart: always
    command: redis-server --requirepass Nextcloud123!

  app:
    image: nextcloud:apache
    container_name: nextcloud-server-app
    restart: always
    ports:
      - "8081:80"
    depends_on:
      - db
    volumes:
      - nextcloud_html:/var/www/html
      - nextcloud_config:/var/www/html/config
      - /mnt/gdrive/data:/var/www/html/data
    environment:
      - MYSQL_HOST=db
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextclouduser
      - MYSQL_PASSWORD=Nextcloud123!
      - REDIS_HOST=redis
      - REDIS_HOST_PASSWORD=Nextcloud123!
      - NEXTCLOUD_TRUSTED_DOMAINS=localhost,127.0.0.1:8081,184.105.238.243,184.105.238.243:8081
      - OVERWRITEPROTOCOL=http
      - OVERWRITECLIURL=http://184.105.238.243:8081
      - APACHE_DISABLE_REWRITE_IP=1

volumes:
  nextcloud_db:
  nextcloud_html:
  nextcloud_config:

networks:
  default:
    name: nextcloud-server_nextcloud
DOCKER_EOF

echo "✅ Docker-compose.yml updated with Google Drive mount"

# Verify Google Drive mount
echo ""
echo "🔍 Verifying Google Drive mount..."
if mountpoint -q /mnt/gdrive; then
    echo "✅ Google Drive is mounted"
    echo "📁 Data folder exists: $(ls -d /mnt/gdrive/data 2>/dev/null && echo "YES" || echo "NO")"
else
    echo "❌ Google Drive NOT mounted!"
    echo "   Please mount first with rclone"
    exit 1
fi

# Fix permissions
echo ""
echo "🔒 Fixing permissions..."
sudo chown -R 33:33 /mnt/gdrive/data
sudo chmod -R 0770 /mnt/gdrive/data

# Start containers
echo ""
echo "🚀 Starting containers with Google Drive..."
docker compose up -d

echo ""
echo "⏳ Waiting 20 seconds for startup..."
sleep 20

# Check status
echo ""
echo "📊 Container status:"
docker compose ps

# Verify mount inside container
echo ""
echo "🔍 Verifying mount inside container..."
CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
if [ -n "$CONTAINER" ]; then
    echo "Data directory inside container:"
    docker exec "$CONTAINER" ls -la /var/www/html/data/ 2>/dev/null | head -5
fi

echo ""
echo "🎉 GOOGLE DRIVE RECONNECTED!"
echo ""
echo "✅ File/folder baru di Nextcloud akan sync ke Google Drive"
echo "🔗 Access: http://184.105.238.243:8081"
echo ""
echo "📁 Data location: /mnt/gdrive/data/"
echo "   (check: ls -la /mnt/gdrive/data/)"

