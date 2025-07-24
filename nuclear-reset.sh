#!/bin/bash

echo "☢️  NUCLEAR RESET - DESTROYING EVERYTHING FOR FRESH INSTALL"
echo "=========================================================="
echo "This will COMPLETELY DESTROY:"
echo "• ALL Docker containers (not just Nextcloud)"
echo "• ALL Docker volumes"
echo "• ALL Docker networks"
echo "• ALL Docker images"
echo "• ALL Nextcloud data"
echo "• ALL database data"
echo ""

read -p "Type 'NUCLEAR' to confirm complete destruction: " confirm
if [ "$confirm" != "NUCLEAR" ]; then
    echo "❌ Reset cancelled"
    exit 1
fi

echo ""
echo "💥 Starting NUCLEAR RESET..."

# 1. Stop ALL Docker containers
echo "🛑 Stopping ALL Docker containers..."
docker stop $(docker ps -aq) 2>/dev/null || true

# 2. Remove ALL Docker containers
echo "🗑️ Removing ALL Docker containers..."
docker rm $(docker ps -aq) 2>/dev/null || true

# 3. Remove ALL Docker volumes
echo "💾 Removing ALL Docker volumes..."
docker volume rm $(docker volume ls -q) 2>/dev/null || true

# 4. Remove ALL Docker networks (except default)
echo "🌐 Removing ALL Docker networks..."
docker network rm $(docker network ls -q --filter type=custom) 2>/dev/null || true

# 5. Remove ALL Docker images
echo "🖼️ Removing ALL Docker images..."
docker rmi $(docker images -aq) 2>/dev/null || true

# 6. Nuclear Docker system prune
echo "🧽 Nuclear Docker system cleanup..."
docker system prune -af --volumes

# 7. Clean Google Drive completely
echo "☁️ Nuclear Google Drive cleanup..."
if mountpoint -q /mnt/gdrive; then
    sudo umount /mnt/gdrive 2>/dev/null || true
    sudo fusermount -u /mnt/gdrive 2>/dev/null || true
    sudo fusermount3 -u /mnt/gdrive 2>/dev/null || true
fi

sudo rm -rf /mnt/gdrive/*
sudo mkdir -p /mnt/gdrive

# 8. Restart rclone service
echo "🔄 Restarting rclone service..."
sudo systemctl stop rclone-gdrive
sudo systemctl start rclone-gdrive
sleep 20

# Verify mount
if ! mountpoint -q /mnt/gdrive; then
    echo "❌ Google Drive mount failed!"
    echo "Manually remount:"
    echo "sudo rclone mount alldrive: /mnt/gdrive --config=/home/paperspace/nextcloud-server/rclone/rclone.conf --allow-other --allow-non-empty --uid=33 --gid=33 --umask=007 --vfs-cache-mode=full --daemon"
    exit 1
fi

# 9. Remove project files and recreate
echo "📁 Nuclear project cleanup..."
cd ~
rm -rf ~/nextcloud-server
mkdir -p ~/nextcloud-server
cd ~/nextcloud-server

# 10. Recreate ALL configuration files from scratch
echo "📝 Recreating configuration files..."

# .env file
cat > .env << 'EOF'
# ===== PROJECT CONFIG =====
COMPOSE_PROJECT_NAME=nextcloud-server

# ===== DATABASE CONFIG =====
MYSQL_ROOT_PASSWORD=Nextcloud123!
MYSQL_PASSWORD=Nextcloud123!
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextclouduser

# ===== REDIS CONFIG =====
REDIS_PASSWORD=Nextcloud123!

# ===== NEXTCLOUD CONFIG =====
TRUSTED_DOMAINS=localhost,127.0.0.1,AUTO_IP_WILL_BE_UPDATED,kuromey.eu.org
DOMAIN=kuromey.eu.org

# ===== ADMIN USER (First install) =====
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=Dimas112233!
EOF

# Update IP in .env
NEW_IP=$(curl -s ifconfig.me)
sed -i "s/AUTO_IP_WILL_BE_UPDATED/$NEW_IP/" .env

# MySQL config
mkdir -p mysql-config
cat > mysql-config/my.cnf << 'EOF'
[mysqld]
# Basic Settings
default_authentication_plugin = mysql_native_password

# InnoDB Settings
innodb_buffer_pool_size = 256M
innodb_log_file_size = 32M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1

# Connection Settings
max_connections = 100
wait_timeout = 600
interactive_timeout = 600

# Character Set
character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci

# Skip DNS Lookups
skip_name_resolve = 1

# Disable Binary Logging
skip-log-bin
EOF

# PHP configs
mkdir -p php-config

cat > php-config/uploads.ini << 'EOF'
upload_max_filesize = 10G
post_max_size = 10G
memory_limit = 1G
max_execution_time = 3600
max_input_time = 3600
max_input_vars = 10000
file_uploads = On
max_file_uploads = 500
EOF

cat > php-config/opcache.ini << 'EOF'
[opcache]
opcache.enable = 1
opcache.enable_cli = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 5000
opcache.revalidate_freq = 60
opcache.validate_timestamps = 1
opcache.save_comments = 1
opcache.fast_shutdown = 1
EOF

cat > php-config/apcu.ini << 'EOF'
[apcu]
apc.enabled = 1
apc.shm_size = 64M
apc.ttl = 3600
apc.gc_ttl = 1800
apc.entries_hint = 4096
apc.slam_defense = 1
EOF

# Docker Compose
cat > docker-compose.yml << 'EOF'
services:
  db:
    image: mysql:5.7
    container_name: ${COMPOSE_PROJECT_NAME}-db
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - nextcloud_db:/var/lib/mysql
      - ./mysql-config/my.cnf:/etc/mysql/conf.d/nextcloud.cnf
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
    networks:
      - nextcloud-network

  redis:
    image: redis:alpine
    container_name: ${COMPOSE_PROJECT_NAME}-redis
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 128mb --maxmemory-policy allkeys-lru
    networks:
      - nextcloud-network

  app:
    image: nextcloud:apache
    container_name: ${COMPOSE_PROJECT_NAME}-app
    restart: always
    ports:
      - "8081:80"
    depends_on:
      - db
      - redis
    volumes:
      - nextcloud_html:/var/www/html
      - nextcloud_config:/var/www/html/config
      - /mnt/gdrive/nextcloud-data:/var/www/html/data
      - ./php-config/uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
      - ./php-config/opcache.ini:/usr/local/etc/php/conf.d/opcache.ini
      - ./php-config/apcu.ini:/usr/local/etc/php/conf.d/apcu.ini
    environment:
      - MYSQL_HOST=db
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_HOST_PASSWORD=${REDIS_PASSWORD}
    networks:
      - nextcloud-network

volumes:
  nextcloud_db:
  nextcloud_html:
  nextcloud_config:

networks:
  nextcloud-network:
    driver: bridge
EOF

# 11. Setup fresh Google Drive data directory
echo "📁 Setting up fresh Google Drive data directory..."
sudo mkdir -p /mnt/gdrive/nextcloud-data
sudo chown -R 33:33 /mnt/gdrive/nextcloud-data
sudo chmod -R 0770 /mnt/gdrive/nextcloud-data
echo '# Nextcloud data directory' | sudo tee /mnt/gdrive/nextcloud-data/.ncdata
sudo chown 33:33 /mnt/gdrive/nextcloud-data/.ncdata

# 12. Pull fresh images and deploy
echo "🐳 Pulling fresh Docker images..."
docker compose pull

echo "🚀 Starting fresh deployment..."
docker compose up -d

# 13. Wait for services
echo "⏳ Waiting for services to start..."
sleep 60

# Monitor database
for i in {1..30}; do
    if docker compose logs db | grep -q "ready for connections"; then
        echo "✅ Database ready!"
        break
    fi
    echo "   Waiting for database... ($i/30)"
    sleep 10
done

# 14. Test access
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081)

echo ""
echo "☢️  NUCLEAR RESET COMPLETE!"
echo "=========================="
echo ""
echo "✅ Everything destroyed and recreated:"
echo "   • All Docker containers, volumes, networks, images"
echo "   • All Nextcloud data and configuration"
echo "   • All database data"
echo "   • Fresh Google Drive mount"
echo "   • Fresh project files"
echo ""
echo "📊 Status:"
docker compose ps
echo ""
echo "🌐 Access URLs:"
echo "   Domain: http://kuromey.eu.org"
echo "   IP: http://$NEW_IP:8081"
echo "   Web Status: HTTP $HTTP_CODE"
echo ""
echo "📋 NOW access the setup wizard and configure:"
echo "   Admin Username: admin"
echo "   Admin Password: Dimas112233!"
echo "   Data Folder: /var/www/html/data (DO NOT CHANGE)"
echo ""
echo "   Database: MySQL/MariaDB"
echo "   DB Host: db"
echo "   DB Name: nextcloud"
echo "   DB User: nextclouduser"
echo "   DB Password: Nextcloud123!"
echo ""
echo "🎯 This is 100% fresh installation - setup wizard MUST appear!"