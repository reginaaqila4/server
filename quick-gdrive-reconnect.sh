#!/bin/bash

echo "⚡ QUICK GOOGLE DRIVE RECONNECT"
echo "=============================="
echo "Mengembalikan sync otomatis ke Google Drive"
echo ""

# Check if Google Drive is mounted
if ! mountpoint -q /mnt/gdrive; then
    echo "❌ Google Drive tidak ter-mount!"
    echo "   Jalankan dulu: sudo rclone mount ..."
    exit 1
fi

echo "✅ Google Drive mounted"
echo ""

# Backup current compose
echo "📦 Backing up current docker-compose.yml..."
cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d_%H%M%S)

# Create new compose with Google Drive data
echo "📝 Updating docker-compose.yml for Google Drive sync..."
cat > docker-compose.yml << 'EOF'
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
