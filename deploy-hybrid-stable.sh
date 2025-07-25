#!/bin/bash

echo "🚀 DEPLOY NEXTCLOUD HYBRID STABLE"
echo "📁 Database, Config, Apps, Themes → VPS (Docker volumes)"
echo "📁 User uploads saja → Google Drive"
echo ""

# Get current IP
CURRENT_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "AUTO_IP_WILL_BE_UPDATED")
echo "🌐 Current IP: $CURRENT_IP"

echo ""
echo "🔧 STEP 1: CREATE PROJECT STRUCTURE"
mkdir -p php-config mysql-config

echo ""
echo "🔧 STEP 2: CREATE .env FILE"
cat > .env << EOF
COMPOSE_PROJECT_NAME=nextcloud-hybrid
MYSQL_ROOT_PASSWORD=Nextcloud123!
MYSQL_PASSWORD=Nextcloud123!
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextclouduser
REDIS_PASSWORD=Nextcloud123!
DOMAIN=kuromey.eu.org
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=Dimas112233!
CURRENT_IP=$CURRENT_IP
EOF

echo ""
echo "🔧 STEP 3: CREATE PHP CONFIGS"
cat > php-config/uploads.ini << EOF
upload_max_filesize = 1G
post_max_size = 1G
max_input_time = 3600
max_execution_time = 3600
memory_limit = 256M
EOF

cat > php-config/opcache.ini << EOF
opcache.enable=1
opcache.enable_cli=1
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.memory_consumption=128
opcache.save_comments=1
opcache.revalidate_freq=1
EOF

cat > php-config/apcu.ini << EOF
extension=apcu.so
apc.enabled=1
apc.shm_size=32M
apc.enable_cli=1
EOF

echo ""
echo "🔧 STEP 4: CREATE MYSQL CONFIG"
cat > mysql-config/my.cnf << EOF
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

echo ""
echo "🔧 STEP 5: CREATE DOCKER COMPOSE - HYBRID SETUP"
cat > docker-compose.yml << EOF
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
      - MYSQL_ROOT_PASSWORD=\${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=\${MYSQL_DATABASE}
      - MYSQL_USER=\${MYSQL_USER}
      - MYSQL_PASSWORD=\${MYSQL_PASSWORD}
    networks:
      - nextcloud-network

  redis:
    image: redis:alpine
    container_name: nextcloud-hybrid-redis
    restart: always
    command: redis-server --requirepass \${REDIS_PASSWORD} --maxmemory 128mb --maxmemory-policy allkeys-lru
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
      # SEMUA INI DI VPS (Docker volumes)
      - nextcloud_html:/var/www/html
      - nextcloud_config:/var/www/html/config
      - nextcloud_apps:/var/www/html/custom_apps
      - nextcloud_themes:/var/www/html/themes
      # HANYA uploads yang ke Google Drive
      - /mnt/gdrive/nextcloud-uploads:/var/www/html/data
      # PHP config
      - ./php-config/uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
      - ./php-config/opcache.ini:/usr/local/etc/php/conf.d/opcache.ini
      - ./php-config/apcu.ini:/usr/local/etc/php/conf.d/apcu.ini
    environment:
      - MYSQL_HOST=db
      - MYSQL_DATABASE=\${MYSQL_DATABASE}
      - MYSQL_USER=\${MYSQL_USER}
      - MYSQL_PASSWORD=\${MYSQL_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_HOST_PASSWORD=\${REDIS_PASSWORD}
    networks:
      - nextcloud-network

volumes:
  # SEMUA INI DI VPS
  nextcloud_db:          # Database di VPS
  nextcloud_html:        # Nextcloud app di VPS
  nextcloud_config:      # Config di VPS
  nextcloud_apps:        # Custom apps di VPS
  nextcloud_themes:      # Themes di VPS

networks:
  nextcloud-network:
    driver: bridge
EOF

echo ""
echo "🔧 STEP 6: VERIFY GOOGLE DRIVE MOUNT"
if ! mountpoint -q /mnt/gdrive; then
    echo "❌ Google Drive tidak ter-mount!"
    echo "🔧 Mounting Google Drive..."
    sudo systemctl restart rclone-gdrive
    sleep 5
    if ! mountpoint -q /mnt/gdrive; then
        echo "❌ Gagal mount Google Drive!"
        exit 1
    fi
fi

echo "✅ Google Drive ter-mount"

echo ""
echo "🔧 STEP 7: SETUP GOOGLE DRIVE DIRECTORY"
sudo mkdir -p /mnt/gdrive/nextcloud-uploads
sudo chown -R 33:33 /mnt/gdrive/nextcloud-uploads
sudo chmod -R 0770 /mnt/gdrive/nextcloud-uploads

# Create .ncdata file for Nextcloud
sudo touch /mnt/gdrive/nextcloud-uploads/.ncdata
sudo chown 33:33 /mnt/gdrive/nextcloud-uploads/.ncdata

echo "✅ Google Drive directory ready"

echo ""
echo "🔧 STEP 8: PULL DOCKER IMAGES"
docker compose pull

echo ""
echo "🔧 STEP 9: START CONTAINERS SEQUENTIALLY"
echo "🔄 Starting database..."
docker compose up -d db
echo "⏳ Waiting for database to initialize..."
sleep 30

echo "🔄 Starting Redis..."
docker compose up -d redis
sleep 5

echo "🔄 Starting Nextcloud app..."
docker compose up -d app
echo "⏳ Waiting for Nextcloud to start..."
sleep 30

echo ""
echo "🔧 STEP 10: VERIFY DEPLOYMENT"
echo "📊 Container status:"
docker compose ps

echo ""
echo "🌐 Testing web access..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Web access OK (HTTP $HTTP_CODE)"
else
    echo "❌ Web access failed (HTTP $HTTP_CODE)"
fi

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo ""
echo "📋 HYBRID SETUP SUMMARY:"
echo "   🗄️  Database: VPS Docker volume (nextcloud_db)"
echo "   ⚙️  Config: VPS Docker volume (nextcloud_config)"
echo "   📱 Apps: VPS Docker volume (nextcloud_apps)"
echo "   🎨 Themes: VPS Docker volume (nextcloud_themes)"
echo "   📁 User uploads: Google Drive (/mnt/gdrive/nextcloud-uploads)"
echo ""
echo "🌐 Access Nextcloud:"
echo "   Local: http://localhost:8081"
echo "   IP: http://$CURRENT_IP:8081"
echo ""
echo "🔑 Admin credentials:"
echo "   Username: admin"
echo "   Password: Dimas112233!"
echo ""
echo "🗄️  Database info untuk setup wizard:"
echo "   Database: MySQL/MariaDB"
echo "   Host: db"
echo "   Database name: nextcloud"
echo "   Username: nextclouduser"
echo "   Password: Nextcloud123!"
echo ""
echo "⚠️  PENTING: Jika setup wizard ter-skip, jalankan:"
echo "   ./force-fresh-setup.sh"