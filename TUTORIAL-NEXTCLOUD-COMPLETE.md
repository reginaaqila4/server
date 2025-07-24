# 🚀 **TUTORIAL LENGKAP NEXTCLOUD + GOOGLE DRIVE + SSL DOMAIN + OPTIMASI FULL POWER**

## **🔧 PART 1: PERSIAPAN VPS**

```bash
# Update sistem
sudo apt update && sudo apt upgrade -y
sudo apt install -y git nano htop unzip curl wget ca-certificates gnupg lsb-release fuse fuse3 net-tools

# Buat user (jika login sebagai root)
sudo adduser paperspace
sudo usermod -aG sudo paperspace
su - paperspace
```

## **🐳 PART 2: INSTALL DOCKER**

```bash
# Hapus Docker lama
sudo apt purge docker docker.io containerd runc snapd -y

# Install Docker CE
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
newgrp docker

# Test
docker run hello-world
```

## **☁️ PART 3: INSTALL RCLONE**

```bash
# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Buat config directory
mkdir -p ~/nextcloud-server/rclone

# Setup rclone config
rclone config --config=~/nextcloud-server/rclone/rclone.conf
```

**Setup Google Drive:**
- `n` → `alldrive` → `15` (Google Drive)
- Enter untuk default → `1` (Full access)
- `y` untuk auto config → Login Google
- `y` untuk keep → `q` untuk quit

```bash
# Test koneksi
rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive:
```

## **🗂️ PART 4: MOUNT GOOGLE DRIVE**

```bash
# Buat mount point
sudo mkdir -p /mnt/gdrive

# Mount Google Drive (sementara)
sudo rclone mount alldrive: /mnt/gdrive \
  --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \
  --allow-other --allow-non-empty \
  --uid=33 --gid=33 --umask=007 \
  --vfs-cache-mode=full --vfs-cache-max-size=5G \
  --daemon

sleep 10
mountpoint /mnt/gdrive && echo "✅ Mount berhasil"
```

**Auto-mount service:**
```bash
sudo nano /etc/systemd/system/rclone-gdrive.service
```

**Paste:**
```ini
[Unit]
Description=RClone mount Google Drive
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/rclone mount alldrive: /mnt/gdrive \
  --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \
  --allow-other --allow-non-empty \
  --uid=33 --gid=33 --umask=007 \
  --vfs-cache-mode=full \
  --vfs-cache-max-size=5G \
  --vfs-cache-max-age=1h \
  --dir-cache-time=12h \
  --poll-interval=15s \
  --timeout=1h \
  --drive-chunk-size=32M \
  --buffer-size=32M \
  --daemon=false
ExecStop=/bin/fusermount3 -u /mnt/gdrive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# Aktifkan service
sudo systemctl daemon-reload
sudo systemctl enable rclone-gdrive
sudo systemctl start rclone-gdrive

# Cek status
systemctl status rclone-gdrive
mountpoint /mnt/gdrive && echo "✅ Mount aktif"
```

## **🏗️ PART 5: SETUP NEXTCLOUD PROJECT**

```bash
# Buat project directory
mkdir -p ~/nextcloud-server
cd ~/nextcloud-server

# Clean up old scripts (jika ada)
rm -f *.sh deploy-*.sh fix-*.sh reset-*.sh 2>/dev/null || true

# Setup data directory
sudo rm -rf /mnt/gdrive/nextcloud-data
sudo mkdir -p /mnt/gdrive/nextcloud-data
sudo chown -R 33:33 /mnt/gdrive/nextcloud-data
sudo chmod -R 0770 /mnt/gdrive/nextcloud-data

# Create .ncdata file (PENTING!)
echo '# Nextcloud data directory' | sudo tee /mnt/gdrive/nextcloud-data/.ncdata
sudo chown 33:33 /mnt/gdrive/nextcloud-data/.ncdata
sudo chmod 660 /mnt/gdrive/nextcloud-data/.ncdata
```

**Buat file .env:**
```bash
nano .env
```

**Paste (GANTI kuromey.eu.org dengan domain Anda):**
```env
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
TRUSTED_DOMAINS=localhost,127.0.0.1,184.105.238.243,kuromey.eu.org
DOMAIN=kuromey.eu.org

# ===== ADMIN USER (First install) =====
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=Dimas112233!
```

## **⚙️ PART 6: BUAT KONFIGURASI OPTIMASI**

### **6.1 Buat direktori konfigurasi:**
```bash
mkdir -p php-config mysql-config
```

### **6.2 Buat konfigurasi PHP:**
```bash
nano php-config/uploads.ini
```
**Paste:**
```ini
; PHP Upload Configuration - High Performance
upload_max_filesize = 20G
post_max_size = 20G
memory_limit = 2G
max_execution_time = 43200
max_input_time = 43200
max_input_vars = 20000
file_uploads = On
max_file_uploads = 1000
```

```bash
nano php-config/opcache.ini
```
**Paste:**
```ini
; OPcache Configuration - High Performance
[opcache]
opcache.enable = 1
opcache.enable_cli = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 32
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 60
opcache.validate_timestamps = 1
opcache.save_comments = 1
opcache.fast_shutdown = 1
```

```bash
nano php-config/apcu.ini
```
**Paste:**
```ini
; APCu Configuration - High Performance
[apcu]
apc.enabled = 1
apc.shm_size = 128M
apc.ttl = 7200
apc.gc_ttl = 3600
apc.entries_hint = 8192
apc.slam_defense = 1
```

### **6.3 Buat konfigurasi MySQL:**
```bash
nano mysql-config/my.cnf
```
**Paste:**
```ini
[mysqld]
# Nextcloud MySQL High Performance Optimization

# InnoDB Settings
innodb_buffer_pool_size = 512M
innodb_log_file_size = 64M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1
innodb_flush_method = O_DIRECT

# Connection Settings
max_connections = 200
wait_timeout = 600
interactive_timeout = 600

# Buffer Settings
key_buffer_size = 64M
table_open_cache = 800
sort_buffer_size = 4M
read_buffer_size = 2M
read_rnd_buffer_size = 8M

# Query Cache
query_cache_type = 1
query_cache_size = 128M
query_cache_limit = 4M

# Temporary Tables
tmp_table_size = 128M
max_heap_table_size = 128M

# Character Set
character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci

# Skip DNS Lookups
skip_name_resolve = 1
```

## **🐳 PART 7: BUAT DOCKER COMPOSE OPTIMIZED**

```bash
nano docker-compose.yml
```
**Paste:**
```yaml
services:
  db:
    image: mysql:8.0.36-debian
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
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru --save 60 1000
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
      # PHP Optimizations
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
      - NEXTCLOUD_TRUSTED_DOMAINS=${TRUSTED_DOMAINS}
      - OVERWRITEPROTOCOL=https
      - OVERWRITEHOST=${DOMAIN}
      - OVERWRITE.CLI.URL=https://${DOMAIN}
      # PHP Environment Variables
      - PHP_MEMORY_LIMIT=2G
      - PHP_UPLOAD_MAX_FILESIZE=20G
      - PHP_POST_MAX_SIZE=20G
      - PHP_MAX_EXECUTION_TIME=43200
    networks:
      - nextcloud-network

volumes:
  nextcloud_db:
  nextcloud_html:
  nextcloud_config:

networks:
  nextcloud-network:
    driver: bridge
```

## **🌐 PART 8: SETUP NGINX + SSL**

```bash
# Install Nginx dan Certbot
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

# Start dan enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

**Buat konfigurasi Nginx:**
```bash
sudo nano /etc/nginx/sites-available/kuromey.eu.org
```

**Paste (ganti kuromey.eu.org dengan domain Anda):**
```nginx
server {
    listen 80;
    server_name kuromey.eu.org;
    
    # Allow Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }
    
    # Redirect all other HTTP to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name kuromey.eu.org;

    # SSL Configuration (will be added by certbot)
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "no-referrer-when-downgrade";

    # Client max body size (for large file uploads)
    client_max_body_size 20G;
    client_body_timeout 43200s;
    client_header_timeout 43200s;

    # Proxy settings
    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeouts
        proxy_connect_timeout 43200s;
        proxy_send_timeout 43200s;
        proxy_read_timeout 43200s;
        
        # WebDAV support
        proxy_set_header Destination $http_destination;
        proxy_pass_request_headers on;
    }

    # Optimize for Nextcloud
    location = /.well-known/carddav {
        return 301 $scheme://$host/remote.php/dav;
    }
    
    location = /.well-known/caldav {
        return 301 $scheme://$host/remote.php/dav;
    }
    
    location = /.well-known/webfinger {
        return 301 $scheme://$host/index.php/.well-known/webfinger;
    }
    
    location = /.well-known/nodeinfo {
        return 301 $scheme://$host/index.php/.well-known/nodeinfo;
    }
}
```

**Enable site:**
```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/kuromey.eu.org /etc/nginx/sites-enabled/

# Remove default site
sudo rm /etc/nginx/sites-enabled/default

# Test nginx config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

## **🚀 PART 9: BUAT SCRIPT DEPLOYMENT**

```bash
nano deploy-nextcloud.sh
```
**Paste:**
```bash
#!/bin/bash

echo "🚀 Deploying Optimized Nextcloud with SSL Domain..."

# Load environment variables
source .env

# Verify Google Drive mount
if ! mountpoint -q /mnt/gdrive; then
    echo "❌ Google Drive not mounted!"
    echo "Starting rclone service..."
    sudo systemctl start rclone-gdrive
    sleep 10
    
    if ! mountpoint -q /mnt/gdrive; then
        echo "❌ Failed to mount Google Drive!"
        exit 1
    fi
fi

echo "✅ Google Drive mounted successfully"

# Clean up any existing containers
echo "🧹 Cleaning up existing containers..."
docker compose down --volumes 2>/dev/null || true

# Remove old volumes to prevent conflicts
echo "🗑️ Removing old volumes..."
docker volume rm nextcloud-server_nextcloud_db 2>/dev/null || true

# Start database first
echo "🗄️ Starting database..."
docker compose up -d db

# Wait for database initialization
echo "⏳ Waiting for database initialization..."
sleep 30

# Check database readiness
for i in {1..30}; do
    if docker compose logs db | grep -q "ready for connections"; then
        echo "✅ Database ready!"
        break
    fi
    echo "   Waiting for database... ($i/30)"
    sleep 3
done

# Start Redis
echo "⚡ Starting Redis..."
docker compose up -d redis
sleep 5

# Start Nextcloud
echo "🌐 Starting Nextcloud..."
docker compose up -d app
sleep 20

# Final status check
echo "📊 Deployment status:"
docker compose ps

# Test database connection
echo "🔍 Testing database connection..."
if docker compose exec db mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ Database connection OK"
else
    echo "❌ Database connection failed"
fi

# Test web access
echo "🌐 Testing web access..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081)
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
    echo "✅ Web access OK (HTTP $HTTP_CODE)"
else
    echo "❌ Web access issue (HTTP $HTTP_CODE)"
fi

echo ""
echo "🎉 Optimized Nextcloud deployment complete!"
echo ""
echo "📊 Performance Features Enabled:"
echo "   ✓ Redis Caching (256MB)"
echo "   ✓ PHP OPcache + APCu (High Performance)"
echo "   ✓ MySQL InnoDB Optimization"
echo "   ✓ Large File Upload (20GB)"
echo "   ✓ Google Drive Auto Storage"
echo ""
echo "🌐 Access: http://$(curl -s ifconfig.me):8081"
echo "🌐 Domain: https://${DOMAIN} (after SSL setup)"
echo "📂 All uploads automatically go to Google Drive"
echo ""
echo "📋 Database Credentials for Web Setup:"
echo "   Database: MySQL/MariaDB"
echo "   Host: db"
echo "   Database: nextcloud"
echo "   User: nextclouduser"
echo "   Password: ${MYSQL_PASSWORD}"
```

```bash
chmod +x deploy-nextcloud.sh
```

## **🔒 PART 10: SETUP SSL CERTIFICATE**

```bash
nano setup-ssl.sh
```
**Paste:**
```bash
#!/bin/bash

echo "🔒 Setting up SSL certificate..."

# Get domain from .env
source .env
DOMAIN_NAME=${DOMAIN}

echo "🌐 Setting up SSL for: $DOMAIN_NAME"

# Create webroot directory
sudo mkdir -p /var/www/html
sudo chown -R www-data:www-data /var/www/html

# Get SSL certificate using webroot method
sudo certbot certonly --webroot -w /var/www/html -d $DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME

if [ $? -eq 0 ]; then
    echo "✅ SSL certificate obtained successfully!"
    
    # Update nginx config with SSL settings
    sudo sed -i '/# SSL Configuration/a\    ssl_certificate /etc/letsencrypt/live/'$DOMAIN_NAME'/fullchain.pem;\n    ssl_certificate_key /etc/letsencrypt/live/'$DOMAIN_NAME'/privkey.pem;\n    ssl_protocols TLSv1.2 TLSv1.3;\n    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;\n    ssl_prefer_server_ciphers off;\n    ssl_session_cache shared:SSL:10m;\n    ssl_session_timeout 10m;' /etc/nginx/sites-available/$DOMAIN_NAME
    
    # Reload nginx
    sudo nginx -t && sudo systemctl reload nginx
    
    # Test SSL
    echo "🔍 Testing SSL..."
    curl -I https://$DOMAIN_NAME
    
    echo ""
    echo "🎉 SSL setup complete!"
    echo "🌐 Your Nextcloud is now accessible at: https://$DOMAIN_NAME"
else
    echo "❌ SSL certificate setup failed!"
    echo "Please check your DNS settings and try again"
    echo "Make sure $DOMAIN_NAME points to your server IP"
fi
```

```bash
chmod +x setup-ssl.sh
```

## **⚙️ PART 11: UPDATE NEXTCLOUD CONFIG FOR DOMAIN**

```bash
nano update-domain-config.sh
```
**Paste:**
```bash
#!/bin/bash

echo "🌐 Updating Nextcloud configuration for SSL domain..."

# Get domain from .env
source .env
DOMAIN_NAME=${DOMAIN}
VPS_IP=$(curl -s ifconfig.me)

# Wait for Nextcloud to be ready
echo "⏳ Waiting for Nextcloud to be ready..."
sleep 10

# Update trusted domains
docker exec nextcloud-server-app php /var/www/html/occ config:system:set trusted_domains 0 --value=localhost
docker exec nextcloud-server-app php /var/www/html/occ config:system:set trusted_domains 1 --value=127.0.0.1
docker exec nextcloud-server-app php /var/www/html/occ config:system:set trusted_domains 2 --value=$VPS_IP
docker exec nextcloud-server-app php /var/www/html/occ config:system:set trusted_domains 3 --value=$VPS_IP:8081
docker exec nextcloud-server-app php /var/www/html/occ config:system:set trusted_domains 4 --value=$DOMAIN_NAME

# Set overwrite settings for HTTPS
docker exec nextcloud-server-app php /var/www/html/occ config:system:set overwriteprotocol --value=https
docker exec nextcloud-server-app php /var/www/html/occ config:system:set overwritehost --value=$DOMAIN_NAME
docker exec nextcloud-server-app php /var/www/html/occ config:system:set overwrite.cli.url --value=https://$DOMAIN_NAME

# Set proxy headers
docker exec nextcloud-server-app php /var/www/html/occ config:system:set trusted_proxies 0 --value=127.0.0.1
docker exec nextcloud-server-app php /var/www/html/occ config:system:set forwarded_for_headers 0 --value=HTTP_X_FORWARDED_FOR

echo "✅ Nextcloud configuration updated!"
echo "🌐 Your Nextcloud is now configured for: https://$DOMAIN_NAME"

# Test configuration
echo "🔍 Current trusted domains:"
docker exec nextcloud-server-app php /var/www/html/occ config:system:get trusted_domains
```

```bash
chmod +x update-domain-config.sh
```

## **🔄 PART 12: BUAT SCRIPT BACKUP LENGKAP**

```bash
nano backup-nextcloud-complete.sh
```
**Paste:**
```bash
#!/bin/bash

# Nextcloud Complete Backup Script - Enhanced Version
BACKUP_DIR="/mnt/gdrive/backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="nextcloud_complete_backup_$TIMESTAMP"
TEMP_BACKUP="/tmp/$BACKUP_NAME"

echo "🔄 Starting Complete Nextcloud Backup..."
echo "📅 Timestamp: $TIMESTAMP"

# Check if containers are running
if ! docker ps | grep -q "nextcloud-server-app"; then
    echo "❌ Nextcloud containers are not running!"
    exit 1
fi

# Create backup directories
mkdir -p "$TEMP_BACKUP"
mkdir -p "$BACKUP_DIR"

# Enable maintenance mode
echo "🔧 Enabling maintenance mode..."
docker exec nextcloud-server-app php /var/www/html/occ maintenance:mode --on 2>/dev/null || true

# 1. Backup Database
echo "🗄️ Backing up MySQL database..."
docker exec nextcloud-server-db mysqldump -u root -pNextcloud123! --single-transaction --routines --triggers nextcloud > "$TEMP_BACKUP/database.sql"
if [ $? -eq 0 ]; then
    echo "✅ Database backup completed ($(du -h "$TEMP_BACKUP/database.sql" | cut -f1))"
else
    echo "❌ Database backup failed"
    docker exec nextcloud-server-app php /var/www/html/occ maintenance:mode --off 2>/dev/null
    exit 1
fi

# 2. Backup ALL Config Files
echo "📋 Backing up ALL Nextcloud configuration files..."
mkdir -p "$TEMP_BACKUP/config"
docker exec nextcloud-server-app tar -czf - -C /var/www/html/config . | tar -xzf - -C "$TEMP_BACKUP/config"
if [ $? -eq 0 ]; then
    echo "✅ All config files backed up:"
    echo "   Files: $(ls "$TEMP_BACKUP/config/" | wc -l)"
    echo "   Including: config.php, redis.config.php, apps.config.php, etc."
else
    echo "❌ Config backup failed"
fi

# 3. Backup Custom Apps
echo "📱 Backing up custom apps..."
if docker exec nextcloud-server-app test -d /var/www/html/custom_apps; then
    mkdir -p "$TEMP_BACKUP/custom_apps"
    docker exec nextcloud-server-app tar -czf - -C /var/www/html/custom_apps . | tar -xzf - -C "$TEMP_BACKUP/custom_apps" 2>/dev/null || mkdir -p "$TEMP_BACKUP/custom_apps"
    echo "✅ Custom apps backed up"
else
    mkdir -p "$TEMP_BACKUP/custom_apps"
    echo "ℹ️ No custom apps found"
fi

# 4. Backup Themes
echo "🎨 Backing up themes..."
if docker exec nextcloud-server-app test -d /var/www/html/themes; then
    mkdir -p "$TEMP_BACKUP/themes"
    docker exec nextcloud-server-app tar -czf - -C /var/www/html/themes . | tar -xzf - -C "$TEMP_BACKUP/themes" 2>/dev/null || mkdir -p "$TEMP_BACKUP/themes"
    echo "✅ Themes backed up"
else
    mkdir -p "$TEMP_BACKUP/themes"
    echo "ℹ️ No custom themes found"
fi

# 5. Backup Docker Setup + SSL Config
echo "🐳 Backing up Docker and SSL configuration..."
mkdir -p "$TEMP_BACKUP/docker-setup"
cp docker-compose.yml "$TEMP_BACKUP/docker-setup/" 2>/dev/null || echo "Warning: docker-compose.yml not found"
cp .env "$TEMP_BACKUP/docker-setup/" 2>/dev/null || echo "Warning: .env file not found"
cp -r php-config "$TEMP_BACKUP/docker-setup/" 2>/dev/null || echo "Warning: php-config not found"
cp -r mysql-config "$TEMP_BACKUP/docker-setup/" 2>/dev/null || echo "Warning: mysql-config not found"
cp -r rclone "$TEMP_BACKUP/docker-setup/" 2>/dev/null || echo "Warning: rclone config not found"

# Backup Nginx SSL config
mkdir -p "$TEMP_BACKUP/ssl-config"
sudo cp /etc/nginx/sites-available/* "$TEMP_BACKUP/ssl-config/" 2>/dev/null || echo "Warning: Nginx config not found"
sudo cp -r /etc/letsencrypt "$TEMP_BACKUP/ssl-config/" 2>/dev/null || echo "Warning: SSL certificates not found"

# Disable maintenance mode
echo "🔧 Disabling maintenance mode..."
docker exec nextcloud-server-app php /var/www/html/occ maintenance:mode --off 2>/dev/null || true

# Create compressed archive
echo "📦 Creating compressed backup archive..."
cd /tmp
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
BACKUP_SIZE=$(du -h "$BACKUP_NAME.tar.gz" | cut -f1)

# Move to Google Drive
echo "☁️ Moving backup to Google Drive..."
mv "$BACKUP_NAME.tar.gz" "$BACKUP_DIR/"

# Cleanup temp files
echo "🧹 Cleaning up temporary files..."
rm -rf "$TEMP_BACKUP"

# Keep only last 10 backups
echo "📂 Managing backup retention (keeping last 10)..."
cd "$BACKUP_DIR"
ls -t nextcloud_complete_backup_*.tar.gz | tail -n +11 | xargs -r rm

echo ""
echo "🎉 Complete backup finished successfully!"
echo "📁 Backup location: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "📊 Backup size: $BACKUP_SIZE"
echo ""
echo "📋 Recent backups:"
ls -lah "$BACKUP_DIR"/nextcloud_complete_backup_*.tar.gz | tail -5
```

```bash
chmod +x backup-nextcloud-complete.sh
```

## **🔄 PART 13: BUAT SCRIPT RESTORE LENGKAP**

```bash
nano restore-nextcloud-complete.sh
```
**Paste:**
```bash
#!/bin/bash

# Nextcloud Complete Restore Script with SSL Domain
BACKUP_DIR="/mnt/gdrive/backup"

if [ -z "$1" ]; then
    echo "❌ Please provide backup file name"
    echo "Usage: $0 <backup_filename.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -la "$BACKUP_DIR"/nextcloud_complete_backup_*.tar.gz 2>/dev/null | tail -5
    exit 1
fi

BACKUP_FILE="$1"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

if [ ! -f "$BACKUP_PATH" ]; then
    echo "❌ Backup file not found: $BACKUP_PATH"
    exit 1
fi

echo "🔄 Starting Complete Nextcloud Restore with SSL Domain..."
echo "📁 Backup file: $BACKUP_FILE"
echo "📊 Backup size: $(du -h "$BACKUP_PATH" | cut -f1)"

# Confirmation
read -p "⚠️ This will REPLACE your current Nextcloud installation completely. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Restore cancelled"
    exit 1
fi

# Extract backup
echo "📦 Extracting backup archive..."
cd /tmp
tar -xzf "$BACKUP_PATH"
BACKUP_NAME=$(basename "$BACKUP_FILE" .tar.gz)
EXTRACTED_DIR="/tmp/$BACKUP_NAME"

if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "❌ Failed to extract backup or invalid backup structure"
    exit 1
fi

# Stop containers
echo "📦 Stopping Nextcloud containers..."
docker compose down --volumes 2>/dev/null || true

# Restore Docker Setup first
echo "🐳 Restoring Docker configuration..."
if [ -d "$EXTRACTED_DIR/docker-setup" ]; then
    cd ~/nextcloud-server
    cp "$EXTRACTED_DIR/docker-setup/docker-compose.yml" . 2>/dev/null && echo "✅ docker-compose.yml restored"
    cp "$EXTRACTED_DIR/docker-setup/.env" . 2>/dev/null && echo "✅ .env restored"
    cp -r "$EXTRACTED_DIR/docker-setup/php-config" . 2>/dev/null && echo "✅ php-config restored"
    cp -r "$EXTRACTED_DIR/docker-setup/mysql-config" . 2>/dev/null && echo "✅ mysql-config restored"
    cp -r "$EXTRACTED_DIR/docker-setup/rclone" . 2>/dev/null && echo "✅ rclone config restored"
fi

# Restore SSL Configuration
echo "🔒 Restoring SSL configuration..."
if [ -d "$EXTRACTED_DIR/ssl-config" ]; then
    sudo cp "$EXTRACTED_DIR/ssl-config"/* /etc/nginx/sites-available/ 2>/dev/null && echo "✅ Nginx config restored"
    sudo cp -r "$EXTRACTED_DIR/ssl-config/letsencrypt" /etc/ 2>/dev/null && echo "✅ SSL certificates restored"
    sudo systemctl reload nginx 2>/dev/null || echo "⚠️ Nginx not running"
fi

# Start database
echo "🗄️ Starting database..."
docker compose up -d db
sleep 20

# Restore database
echo "🗄️ Restoring database..."
docker compose exec -i db mysql -u root -pNextcloud123! -e "DROP DATABASE IF EXISTS nextcloud; CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
docker compose exec -i db mysql -u root -pNextcloud123! nextcloud < "$EXTRACTED_DIR/database.sql"

# Start all containers
echo "🔄 Starting all containers..."
docker compose up -d
sleep 20

# Restore config files
echo "📋 Restoring configuration files..."
if [ -d "$EXTRACTED_DIR/config" ]; then
    docker exec nextcloud-server-app rm -rf /var/www/html/config/*
    cd "$EXTRACTED_DIR/config"
    tar -czf - . | docker exec -i nextcloud-server-app tar -xzf - -C /var/www/html/config
    docker exec nextcloud-server-app chown -R www-data:www-data /var/www/html/config
    echo "✅ Configuration files restored"
fi

# Update domain configuration
echo "🌐 Updating domain configuration..."
source ~/nextcloud-server/.env 2>/dev/null || true
if [ ! -z "$DOMAIN" ]; then
    ./update-domain-config.sh
fi

# Cleanup
echo "🧹 Cleaning up temporary files..."
rm -rf "$EXTRACTED_DIR"

echo ""
echo "🎉 Complete Nextcloud restore finished successfully!"
echo "🌐 Access your restored Nextcloud at: https://$DOMAIN"
```

```bash
chmod +x restore-nextcloud-complete.sh
```

## **⏰ PART 14: SETUP AUTO BACKUP**

```bash
nano setup-auto-backup.sh
```
**Paste:**
```bash
#!/bin/bash

echo "⏰ Setting up automatic Nextcloud backup..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-nextcloud-complete.sh"

# Make backup script executable
chmod +x "$BACKUP_SCRIPT"

# Create cron job (every 12 hours at 2 AM and 2 PM)
CRON_JOB="0 2,14 * * * $BACKUP_SCRIPT >> /var/log/nextcloud-backup.log 2>&1"

# Add to crontab
(crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "$CRON_JOB") | crontab -

echo "✅ Automatic backup configured!"
echo "📅 Schedule: Every 12 hours (2 AM and 2 PM)"
echo "📁 Backup location: /mnt/gdrive/backup/"
echo "📝 Logs: /var/log/nextcloud-backup.log"
```

```bash
chmod +x setup-auto-backup.sh
```

## **📊 PART 15: PERFORMANCE MONITORING**

```bash
nano monitor-performance.sh
```
**Paste:**
```bash
#!/bin/bash

echo "📊 Nextcloud High Performance Monitor"
echo "===================================="

# Get domain from .env
source .env 2>/dev/null || true
DOMAIN_NAME=${DOMAIN:-"not-configured"}

echo "🌐 Domain: https://$DOMAIN_NAME"
echo "🌐 IP Access: http://$(curl -s ifconfig.me):8081"
echo ""

echo "🐳 Container Status:"
docker compose ps

echo ""
echo "💾 Memory Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

echo ""
echo "🌐 Web Response Test:"
if [ "$DOMAIN_NAME" != "not-configured" ]; then
    echo "Testing HTTPS domain..."
    HTTPS_RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" https://$DOMAIN_NAME 2>/dev/null || echo "failed")
    HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN_NAME 2>/dev/null || echo "failed")
    echo "HTTPS Response Time: ${HTTPS_RESPONSE_TIME}s (Code: $HTTPS_CODE)"
fi

echo ""
echo "📁 Google Drive Status:"
if mountpoint -q /mnt/gdrive; then
    echo "✅ Google Drive mounted"
    echo "Files: $(find /mnt/gdrive/nextcloud-data -type f 2>/dev/null | wc -l) files in data directory"
else
    echo "❌ Google Drive not mounted"
fi

echo ""
echo "⚡ Performance Settings:"
echo "Redis Memory: $(docker exec nextcloud-server-redis redis-cli info memory 2>/dev/null | grep used_memory_human | cut -d: -f2 || echo "N/A")"
echo "PHP Memory Limit: $(docker exec nextcloud-server-app php -r "echo ini_get('memory_limit');" 2>/dev/null || echo "N/A")"
echo "Upload Limit: $(docker exec nextcloud-server-app php -r "echo ini_get('upload_max_filesize');" 2>/dev/null || echo "N/A")"
```

```bash
chmod +x monitor-performance.sh
```

## **🚀 PART 16: MASTER DEPLOYMENT SCRIPT**

```bash
nano deploy-complete.sh
```
**Paste:**
```bash
#!/bin/bash

echo "🚀 Complete Nextcloud Deployment with SSL Domain"
echo "================================================"

# Check if domain is configured
source .env 2>/dev/null || { echo "❌ .env file not found!"; exit 1; }
if [ -z "$DOMAIN" ]; then
    echo "❌ Domain not configured in .env file!"
    exit 1
fi

echo "🌐 Deploying for domain: $DOMAIN"
echo ""

# Step 1: Deploy Nextcloud
echo "📦 Step 1: Deploying Nextcloud containers..."
./deploy-nextcloud.sh

if [ $? -ne 0 ]; then
    echo "❌ Nextcloud deployment failed!"
    exit 1
fi

echo ""
echo "⏳ Waiting for Nextcloud to be fully ready..."
sleep 30

# Step 2: Setup SSL
echo "🔒 Step 2: Setting up SSL certificate..."
./setup-ssl.sh

# Step 3: Update domain configuration
echo "🌐 Step 3: Updating Nextcloud domain configuration..."
./update-domain-config.sh

# Step 4: Setup auto backup
echo "⏰ Step 4: Setting up automatic backup..."
./setup-auto-backup.sh

echo ""
echo "🎉 Complete deployment finished!"
echo ""
echo "📊 Your Nextcloud is ready with:"
echo "   ✅ High-performance optimization (Redis, OPcache, MySQL tuning)"
echo "   ✅ SSL certificate and HTTPS access"
echo "   ✅ Large file upload support (20GB)"
echo "   ✅ Google Drive automatic storage"
echo "   ✅ Automatic backup every 12 hours"
echo ""
echo "🌐 Access URLs:"
echo "   HTTPS (Primary): https://$DOMAIN"
echo "   HTTP (Fallback): http://$(curl -s ifconfig.me):8081"
echo ""
echo "📋 Next steps:"
echo "   1. Access https://$DOMAIN and complete web setup"
echo "   2. Use these database credentials:"
echo "      Database: MySQL/MariaDB"
echo "      Host: db"
echo "      Database: nextcloud"
echo "      User: nextclouduser"
echo "      Password: Nextcloud123!"
echo "   3. Monitor performance: ./monitor-performance.sh"
echo "   4. Manual backup: ./backup-nextcloud-complete.sh"
```

```bash
chmod +x deploy-complete.sh
```

## **🎯 PART 17: QUICK COMMANDS SUMMARY**

```bash
nano quick-commands.sh
```
**Paste:**
```bash
#!/bin/bash

echo "🚀 Nextcloud Quick Commands"
echo "=========================="
echo ""
echo "📦 Deployment:"
echo "   ./deploy-complete.sh        # Complete deployment with SSL"
echo "   ./deploy-nextcloud.sh       # Deploy Nextcloud only"
echo "   ./setup-ssl.sh             # Setup SSL certificate"
echo "   ./update-domain-config.sh  # Update domain settings"
echo ""
echo "🔄 Backup & Restore:"
echo "   ./backup-nextcloud-complete.sh              # Manual backup"
echo "   ./restore-nextcloud-complete.sh <file>      # Restore from backup"
echo "   ./setup-auto-backup.sh                      # Setup auto backup"
echo ""
echo "📊 Monitoring:"
echo "   ./monitor-performance.sh    # Performance monitor"
echo "   docker compose ps           # Container status"
echo "   docker compose logs -f app  # Live logs"
echo ""
echo "🌐 Access:"
echo "   https://$(grep DOMAIN= .env | cut -d'=' -f2)  # Primary HTTPS access"
echo "   http://$(curl -s ifconfig.me):8081            # Fallback HTTP access"
```

```bash
chmod +x quick-commands.sh
```

## **🚀 PART 18: FINAL DEPLOYMENT**

Sekarang jalankan deployment lengkap:

```bash
# Deploy everything
./deploy-complete.sh
```

## **🌐 PART 19: WEB SETUP**

**Akses:** `https://kuromey.eu.org` (ganti dengan domain Anda)

**Form Setup:**
- **Admin Username:** `admin`
- **Admin Password:** `Dimas112233!`
- **Data Folder:** `/var/www/html/data` ⚠️ **JANGAN UBAH**
- **Database:** `MySQL/MariaDB`
- **DB Host:** `db`
- **DB Name:** `nextcloud`
- **DB User:** `nextclouduser`
- **DB Password:** `Nextcloud123!`

**Klik "Finish Setup"**

## **✅ HASIL AKHIR**

🎉 **Nextcloud High Performance dengan SSL Domain:**

✅ **HTTPS Domain:** `https://kuromey.eu.org`  
✅ **Auto upload:** Semua file → Google Drive  
✅ **Multi-user ready** dengan semua pengaturan admin tersimpan  
✅ **Performance optimized:**
- Redis Caching (256MB)
- PHP OPcache + APCu (High Performance)
- MySQL InnoDB tuning (512MB buffer pool)
- Large file upload (20GB)

✅ **SSL Certificate:** Let's Encrypt dengan auto-renewal  
✅ **Auto backup:** Setiap 12 jam dengan backup lengkap  
✅ **Complete backup:** Database + Config + Apps + Themes + SSL + Admin settings  
✅ **VPS tidak penuh:** Data di Google Drive  
✅ **Easy restore:** Script restore lengkap dengan SSL  

**Script yang tersedia:**
- `deploy-complete.sh` - Deploy lengkap dengan SSL
- `backup-nextcloud-complete.sh` - Backup lengkap termasuk admin settings
- `restore-nextcloud-complete.sh` - Restore lengkap dengan SSL
- `monitor-performance.sh` - Monitor performa tinggi
- `quick-commands.sh` - Daftar perintah cepat

**User upload → Otomatis ke Google Drive dengan akses HTTPS yang aman!** 🚀🔒

Semua pengaturan admin, email, tema, user, dan konfigurasi akan ter-backup lengkap dan bisa di-restore 100% identik!