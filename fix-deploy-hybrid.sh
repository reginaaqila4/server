#!/bin/bash

echo "🔧 FIX & DEPLOY NEXTCLOUD HYBRID"
echo "📁 Mengatasi permission error dan Docker issues"
echo ""

# Get current user and directory
CURRENT_USER=$(whoami)
CURRENT_DIR=$(pwd)
echo "👤 Current user: $CURRENT_USER"
echo "📁 Current directory: $CURRENT_DIR"

echo ""
echo "🛠️ STEP 1: FIX DOCKER SYSTEM"
# Stop all containers
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# Clean Docker system
sudo systemctl stop docker
sudo rm -rf /var/lib/docker/containers/* 2>/dev/null || true
sudo systemctl start docker
sleep 5

echo "✅ Docker system cleaned"

echo ""
echo "🛠️ STEP 2: CREATE PROJECT STRUCTURE WITH PROPER PERMISSIONS"
mkdir -p nextcloud-hybrid
cd nextcloud-hybrid

# Create config directories
mkdir -p php-config mysql-config rclone

echo "✅ Project structure created"

echo ""
echo "🛠️ STEP 3: CREATE .env FILE"
cat > .env << 'EOF'
COMPOSE_PROJECT_NAME=nextcloud-hybrid
MYSQL_ROOT_PASSWORD=Nextcloud123!
MYSQL_PASSWORD=Nextcloud123!
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextclouduser
REDIS_PASSWORD=Nextcloud123!
EOF

echo "✅ .env file created"

echo ""
echo "🛠️ STEP 4: CREATE PHP CONFIGS"
cat > php-config/uploads.ini << 'EOF'
upload_max_filesize = 1G
post_max_size = 1G
max_input_time = 3600
max_execution_time = 3600
memory_limit = 256M
EOF

cat > php-config/opcache.ini << 'EOF'
opcache.enable=1
opcache.enable_cli=1
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.memory_consumption=128
opcache.save_comments=1
opcache.revalidate_freq=1
EOF

cat > php-config/apcu.ini << 'EOF'
extension=apcu.so
apc.enabled=1
apc.shm_size=32M
apc.enable_cli=1
EOF

echo "✅ PHP configs created"

echo ""
echo "🛠️ STEP 5: CREATE MYSQL CONFIG"
cat > mysql-config/my.cnf << 'EOF'
[mysqld]
default_authentication_plugin = mysql_native_password
innodb_buffer_pool_size = 256M
innodb_log_file_size = 32M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1
max_connections = 100
wait_timeout = 600
interactive_timeout = 600
character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci
skip_name_resolve = 1
skip-log-bin
EOF

echo "✅ MySQL config created"

echo ""
echo "🛠️ STEP 6: CREATE DOCKER COMPOSE"
cat > docker-compose.yml << 'EOF'
services:
  db:
    image: mysql:5.7
    container_name: nextcloud-hybrid-db
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
    container_name: nextcloud-hybrid-redis
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 128mb --maxmemory-policy allkeys-lru
    networks:
      - nextcloud-network

  app:
    image: nextcloud:apache
    container_name: nextcloud-hybrid-app
    restart: always
    ports:
      - "8081:80"
    depends_on:
      - db
      - redis
    volumes:
      # VPS Docker volumes
      - nextcloud_html:/var/www/html
      - nextcloud_config:/var/www/html/config
      - nextcloud_apps:/var/www/html/custom_apps
      - nextcloud_themes:/var/www/html/themes
      # Google Drive untuk uploads
      - /mnt/gdrive/nextcloud-uploads:/var/www/html/data
      # PHP configs
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
  nextcloud_apps:
  nextcloud_themes:

networks:
  nextcloud-network:
    driver: bridge
EOF

echo "✅ Docker compose created"

echo ""
echo "🛠️ STEP 7: SETUP GOOGLE DRIVE DIRECTORY"
# Check if Google Drive is mounted
if mountpoint -q /mnt/gdrive 2>/dev/null; then
    echo "✅ Google Drive is mounted"
    sudo mkdir -p /mnt/gdrive/nextcloud-uploads
    sudo chown -R 33:33 /mnt/gdrive/nextcloud-uploads
    sudo chmod -R 0770 /mnt/gdrive/nextcloud-uploads
    sudo touch /mnt/gdrive/nextcloud-uploads/.ncdata
    sudo chown 33:33 /mnt/gdrive/nextcloud-uploads/.ncdata
    echo "✅ Google Drive directory ready"
else
    echo "⚠️ Google Drive not mounted, creating local directory for testing"
    sudo mkdir -p /tmp/nextcloud-uploads
    sudo chown -R 33:33 /tmp/nextcloud-uploads
    sudo chmod -R 0770 /tmp/nextcloud-uploads
    sudo touch /tmp/nextcloud-uploads/.ncdata
    sudo chown 33:33 /tmp/nextcloud-uploads/.ncdata
    
    # Update docker-compose to use local directory
    sed -i 's|/mnt/gdrive/nextcloud-uploads:/var/www/html/data|/tmp/nextcloud-uploads:/var/www/html/data|' docker-compose.yml
    echo "⚠️ Using local directory /tmp/nextcloud-uploads for testing"
fi

echo ""
echo "🛠️ STEP 8: DEPLOY CONTAINERS"
echo "🔄 Pulling images..."
docker compose pull

echo ""
echo "🔄 Starting database..."
docker compose up -d db
sleep 20

echo "🔄 Checking database status..."
for i in {1..10}; do
    if docker compose logs db 2>/dev/null | grep -q "ready for connections"; then
        echo "✅ Database ready!"
        break
    fi
    echo "   Waiting for database... ($i/10)"
    sleep 5
done

echo ""
echo "🔄 Starting Redis..."
docker compose up -d redis
sleep 5

echo ""
echo "🔄 Starting Nextcloud..."
docker compose up -d app
sleep 20

echo ""
echo "🛠️ STEP 9: VERIFY DEPLOYMENT"
echo "📊 Container status:"
docker compose ps

echo ""
echo "🌐 Testing web access..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>/dev/null || echo "000")
echo "HTTP response: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Web access OK!"
else
    echo "⚠️ Checking container logs..."
    echo "Database logs:"
    docker compose logs db | tail -5
    echo ""
    echo "App logs:"
    docker compose logs app | tail -5
fi

echo ""
echo "🎉 DEPLOYMENT ATTEMPT COMPLETE!"
echo ""
echo "📋 Project location: $(pwd)"
echo "🌐 Access: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_IP'):8081"
echo ""
echo "🗄️ Database info untuk setup wizard:"
echo "   Database: MySQL/MariaDB"
echo "   Host: db"
echo "   Database name: nextcloud"
echo "   Username: nextclouduser"
echo "   Password: Nextcloud123!"
echo ""
echo "📁 Data folder: /var/www/html/data (JANGAN UBAH)"