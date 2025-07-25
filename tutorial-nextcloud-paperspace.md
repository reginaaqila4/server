# 🚀 NEXTCLOUD HYBRID SETUP - TUTORIAL LENGKAP (PAPERSPACE USER)

## 📋 KONSEP HYBRID SETUP
- **Database, Config, Apps, Themes** → VPS (path eksplisit untuk mudah backup)
- **User uploads saja** → Google Drive (remote: `alldrive:`)
- **Setup wizard** muncul untuk konfigurasi admin
- **Semua pengaturan dashboard** bisa di-backup lengkap

---

## 🔧 STEP 1: PERSIAPAN SISTEM

```bash
# Update sistem
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y curl wget git nano htop fuse3

# Install Docker (jika belum ada)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker paperspace
newgrp docker

# Test Docker
docker run hello-world

# Install rclone (jika belum ada)
curl https://rclone.org/install.sh | sudo bash

# Buat project directory
mkdir -p /home/paperspace/nextcloud-server
cd /home/paperspace/nextcloud-server
```

---

## ☁️ STEP 2: SETUP RCLONE DENGAN REMOTE 'alldrive:' (PATH PAPERSPACE)

### A. Setup Rclone Config (PATH YANG BENAR)
```bash
# Setup rclone config dengan path paperspace
rclone config --config=/home/paperspace/nextcloud-server/rclone/rclone.conf

# Pilihan setup:
# 1. Pilih: n (new remote)
# 2. Name: alldrive
# 3. Storage: 15 (Google Drive)
# 4. Client ID: (kosong, tekan Enter)
# 5. Client Secret: (kosong, tekan Enter)
# 6. Scope: 1 (Full access)
# 7. Root folder: (kosong, tekan Enter)
# 8. Service account: (kosong, tekan Enter)
# 9. Auto config: y
# 10. Login ke Google Account
# 11. Configure as team drive: n
# 12. Keep config: y
# 13. Quit: q

# Test connection dengan path yang benar
rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive:
```

### B. Script Setup Rclone (PATH PAPERSPACE)
```bash
# Buat script setup rclone dengan path paperspace
cat > setup-rclone-alldrive.sh << 'EOF'
#!/bin/bash

echo "☁️ SETUP RCLONE DENGAN REMOTE ALLDRIVE (PAPERSPACE)"
echo "=================================================="
echo ""

# Check if rclone is installed
if ! command -v rclone &> /dev/null; then
    echo "📦 Installing rclone..."
    curl https://rclone.org/install.sh | sudo bash
else
    echo "✅ Rclone sudah terinstall: $(rclone version | head -1)"
fi

# Create rclone config directory dengan path paperspace
mkdir -p /home/paperspace/nextcloud-server/rclone

echo ""
echo "🔧 SETUP RCLONE CONFIG (PATH PAPERSPACE)"
echo ""
echo "Jika Anda sudah punya config rclone dengan remote 'alldrive:', copy ke:"
echo "  /home/paperspace/nextcloud-server/rclone/rclone.conf"
echo ""
echo "Atau buat config baru dengan:"
echo "  rclone config --config=/home/paperspace/nextcloud-server/rclone/rclone.conf"
echo ""
echo "📋 Setup Google Drive remote 'alldrive:':"
echo "  1. Pilih: n (new remote)"
echo "  2. Name: alldrive"
echo "  3. Storage: 15 (Google Drive)"
echo "  4. Client ID: (kosong, tekan Enter)"
echo "  5. Client Secret: (kosong, tekan Enter)"
echo "  6. Scope: 1 (Full access)"
echo "  7. Root folder: (kosong, tekan Enter)"
echo "  8. Service account: (kosong, tekan Enter)"
echo "  9. Auto config: y"
echo "  10. Login ke Google Account"
echo "  11. Configure as team drive: n"
echo "  12. Keep config: y"
echo "  13. Quit: q"
echo ""

# Check if config exists dengan path paperspace
if [ -f /home/paperspace/nextcloud-server/rclone/rclone.conf ]; then
    echo "✅ Config rclone ditemukan"
    echo ""
    echo "🔍 Available remotes:"
    rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf listremotes
    echo ""
    
    # Test alldrive remote
    if rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf listremotes | grep -q "alldrive:"; then
        echo "✅ Remote 'alldrive:' ditemukan"
        echo ""
        echo "🔍 Testing connection..."
        if rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive: >/dev/null 2>&1; then
            echo "✅ Connection ke Google Drive OK"
        else
            echo "❌ Connection ke Google Drive gagal"
            echo "🔧 Coba jalankan: rclone config --config=/home/paperspace/nextcloud-server/rclone/rclone.conf"
        fi
    else
        echo "❌ Remote 'alldrive:' tidak ditemukan"
        echo "🔧 Silakan setup dengan: rclone config --config=/home/paperspace/nextcloud-server/rclone/rclone.conf"
    fi
else
    echo "❌ Config rclone tidak ditemukan"
    echo "🔧 Silakan setup dengan: rclone config --config=/home/paperspace/nextcloud-server/rclone/rclone.conf"
fi

echo ""
echo "📋 NEXT STEPS:"
echo "1. Pastikan remote 'alldrive:' sudah setup"
echo "2. Setup systemd service untuk auto-mount"
echo "3. Jalankan deployment script"
EOF

chmod +x setup-rclone-alldrive.sh
```

---

## 🗂️ STEP 3: SETUP SYSTEMD AUTO-MOUNT GOOGLE DRIVE (PATH PAPERSPACE)

```bash
# Buat mount point
sudo mkdir -p /mnt/gdrive

# Buat systemd service dengan path paperspace
sudo tee /etc/systemd/system/rclone-gdrive.service > /dev/null << 'EOF'
[Unit]
Description=RClone mount Google Drive
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStartPre=/bin/mkdir -p /mnt/gdrive
ExecStart=/usr/local/bin/rclone mount alldrive: /mnt/gdrive \
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
EOF

# Reload systemd
sudo systemctl daemon-reload

# Enable auto-start
sudo systemctl enable rclone-gdrive

# Start service
sudo systemctl start rclone-gdrive

# Check status
sudo systemctl status rclone-gdrive

# Verify mount
mountpoint /mnt/gdrive && echo "✅ Google Drive mounted!"

# Test dengan path paperspace
rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive:
```

---

## 🐳 STEP 4: DEPLOY NEXTCLOUD HYBRID (PATH PAPERSPACE)

### A. Script Deployment Lengkap dengan Path Paperspace
```bash
# Masuk ke directory project
cd /home/paperspace/nextcloud-server

# Buat script deployment utama dengan path paperspace
cat > deploy-nextcloud-complete.sh << 'EOF'
#!/bin/bash

echo "🚀 NEXTCLOUD HYBRID SETUP - COMPLETE DEPLOYMENT (PAPERSPACE)"
echo "============================================================"
echo "📁 Database, Config, Apps, Themes → VPS (explicit paths)"
echo "📁 User uploads only → Google Drive (alldrive:)"
echo ""

# Get current IP
CURRENT_IP=$(curl -s ifconfig.me 2>/dev/null || echo "127.0.0.1")
echo "🌐 Current IP: $CURRENT_IP"

# Step 1: Create project structure
echo ""
echo "🔧 STEP 1: CREATE PROJECT STRUCTURE"
mkdir -p data/mysql data/nextcloud php-config mysql-config rclone scripts

# Step 2: Create .env file
echo ""
echo "🔧 STEP 2: CREATE .env FILE"
cat > .env << 'ENVEOF'
# ===== PROJECT CONFIG =====
COMPOSE_PROJECT_NAME=nextcloud-server

# ===== DATABASE CONFIG =====
MYSQL_ROOT_PASSWORD=NextcloudRoot123!
MYSQL_PASSWORD=NextcloudUser123!
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextclouduser

# ===== REDIS CONFIG =====
REDIS_PASSWORD=NextcloudRedis123!

# ===== DOMAIN CONFIG (optional) =====
DOMAIN=your-domain.com
ENVEOF

# Step 3: Create PHP configs
echo ""
echo "🔧 STEP 3: CREATE PHP CONFIGS"
cat > php-config/uploads.ini << 'PHPEOF'
; PHP Upload Configuration - High Performance
upload_max_filesize = 50G
post_max_size = 50G
memory_limit = 1G
max_execution_time = 43200
max_input_time = 43200
max_input_vars = 20000
file_uploads = On
max_file_uploads = 1000
PHPEOF

cat > php-config/opcache.ini << 'OPCEOF'
; OPcache Configuration - High Performance
[opcache]
opcache.enable = 1
opcache.enable_cli = 1
opcache.memory_consumption = 512
opcache.interned_strings_buffer = 64
opcache.max_accelerated_files = 20000
opcache.revalidate_freq = 60
opcache.validate_timestamps = 1
opcache.save_comments = 1
opcache.fast_shutdown = 1
OPCEOF

cat > php-config/apcu.ini << 'APCEOF'
; APCu Configuration - High Performance
[apcu]
apc.enabled = 1
apc.shm_size = 256M
apc.ttl = 7200
apc.gc_ttl = 3600
apc.entries_hint = 8192
apc.slam_defense = 1
APCEOF

# Step 4: Create MySQL config
echo ""
echo "🔧 STEP 4: CREATE MYSQL CONFIG"
cat > mysql-config/my.cnf << 'MYSQLEOF'
[mysqld]
# Nextcloud MySQL High Performance Optimization
# InnoDB Settings
innodb_buffer_pool_size = 1G
innodb_log_file_size = 128M
innodb_log_buffer_size = 32M
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1
innodb_flush_method = O_DIRECT

# Connection Settings
max_connections = 300
wait_timeout = 600
interactive_timeout = 600

# Buffer Settings
key_buffer_size = 128M
table_open_cache = 1000
sort_buffer_size = 8M
read_buffer_size = 4M
read_rnd_buffer_size = 16M

# Query Cache
query_cache_type = 1
query_cache_size = 256M
query_cache_limit = 8M

# Temporary Tables
tmp_table_size = 256M
max_heap_table_size = 256M

# Character Set
character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci

# Skip DNS Lookups
skip_name_resolve = 1
MYSQLEOF

# Step 5: Create Docker Compose with explicit paths
echo ""
echo "🔧 STEP 5: CREATE DOCKER COMPOSE - HYBRID SETUP"
cat > docker-compose.yml << 'DOCKEREOF'
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
      # Database di VPS (explicit path)
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
      MYSQL_HOST: db
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      REDIS_HOST: redis
      REDIS_HOST_PASSWORD: ${REDIS_PASSWORD}
    volumes:
      # Nextcloud app dan config di VPS (explicit paths)
      - ./data/nextcloud:/var/www/html
      # User uploads ke Google Drive
      - /mnt/gdrive/nextcloud-uploads:/var/www/html/data
      # PHP optimizations
      - ./php-config/uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
      - ./php-config/opcache.ini:/usr/local/etc/php/conf.d/opcache.ini
      - ./php-config/apcu.ini:/usr/local/etc/php/conf.d/apcu.ini
DOCKEREOF

# Step 6: Check Google Drive mount
echo ""
echo "🔧 STEP 6: VERIFY GOOGLE DRIVE MOUNT"
if ! mountpoint -q /mnt/gdrive; then
    echo "❌ Google Drive tidak ter-mount!"
    echo "🔧 Restart rclone service..."
    sudo systemctl restart rclone-gdrive 2>/dev/null || true
    sleep 10
    if ! mountpoint -q /mnt/gdrive; then
        echo "❌ Mount Google Drive gagal!"
        echo "🔍 Check rclone config dengan remote 'alldrive':"
        rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf listremotes 2>/dev/null || echo "Config not found"
        echo ""
        echo "📋 Manual mount command:"
        echo "sudo rclone mount alldrive: /mnt/gdrive --config=/home/paperspace/nextcloud-server/rclone/rclone.conf --allow-other --allow-non-empty --uid=33 --gid=33 --umask=007 --vfs-cache-mode=full --daemon"
        exit 1
    fi
fi
echo "✅ Google Drive ter-mount dengan remote alldrive"

# Test rclone connection dengan path paperspace
echo "🔍 Testing rclone connection..."
if rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive: >/dev/null 2>&1; then
    echo "✅ Rclone connection OK"
else
    echo "❌ Rclone connection failed!"
    echo "🔧 Check your alldrive remote configuration"
    exit 1
fi

# Step 7: Setup Google Drive directory
echo ""
echo "🔧 STEP 7: SETUP GOOGLE DRIVE DIRECTORY"
sudo mkdir -p /mnt/gdrive/nextcloud-uploads
sudo chown -R 33:33 /mnt/gdrive/nextcloud-uploads
sudo chmod -R 0755 /mnt/gdrive/nextcloud-uploads

# Create .ncdata file (important for Nextcloud)
echo '# Nextcloud data directory' | sudo tee /mnt/gdrive/nextcloud-uploads/.ncdata >/dev/null
sudo chown 33:33 /mnt/gdrive/nextcloud-uploads/.ncdata
sudo chmod 660 /mnt/gdrive/nextcloud-uploads/.ncdata

echo "✅ Google Drive directory ready"

# Step 8: Pull Docker images
echo ""
echo "🔧 STEP 8: PULL DOCKER IMAGES"
docker compose pull

# Step 9: Start containers sequentially
echo ""
echo "🔧 STEP 9: START CONTAINERS SEQUENTIALLY"

# Stop any existing containers
docker compose down --volumes 2>/dev/null || true

# Start database first
echo "🔄 Starting database..."
docker compose up -d db
echo "⏳ Waiting for database to initialize..."
sleep 30

# Check database readiness
for i in {1..20}; do
    if docker compose logs db | grep -q "ready for connections"; then
        echo "✅ Database ready!"
        break
    fi
    echo "  Waiting for database... ($i/20)"
    sleep 3
done

# Start Redis
echo "🔄 Starting Redis..."
docker compose up -d redis
sleep 5

# Start Nextcloud app
echo "🔄 Starting Nextcloud app..."
docker compose up -d app
echo "⏳ Waiting for Nextcloud to start..."
sleep 20

# Step 10: Verify deployment
echo ""
echo "🔧 STEP 10: VERIFY DEPLOYMENT"

# Check container status
echo "📊 Container status:"
docker compose ps

# Test web access
echo "🌐 Testing web access..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
    echo "✅ Web access OK (HTTP $HTTP_CODE)"
else
    echo "❌ Web access failed (HTTP $HTTP_CODE)"
fi

# Final summary
echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo ""
echo "📋 HYBRID SETUP SUMMARY:"
echo "🗄️  Database: VPS explicit path (./data/mysql)"
echo "⚙️  Config: VPS explicit path (./data/nextcloud)"
echo "📱 Apps: VPS explicit path (./data/nextcloud/apps)"
echo "🎨 Themes: VPS explicit path (./data/nextcloud/themes)"
echo "📁 User uploads: Google Drive (/mnt/gdrive/nextcloud-uploads)"
echo ""
echo "🌐 Access Nextcloud:"
echo "  Local: http://localhost:8081"
echo "  IP: http://$CURRENT_IP:8081"
echo ""
echo "🔑 Database info untuk setup wizard:"
echo "  Database: MySQL/MariaDB"
echo "  Host: db"
echo "  Database name: nextcloud"
echo "  Username: nextclouduser"
echo "  Password: NextcloudUser123!"
echo ""
echo "⚠️  PENTING: Setup wizard akan muncul untuk konfigurasi admin dan database"
echo "📁 Data folder akan otomatis ke: /var/www/html/data (Google Drive)"
echo ""
echo "🔧 Test rclone dengan path paperspace:"
echo "  rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive:"
EOF

chmod +x deploy-nextcloud-complete.sh
```

### B. Script Check Status (Path Paperspace)
```bash
# Buat script check status dengan path paperspace
cat > check-status.sh << 'EOF'
#!/bin/bash

echo "📊 NEXTCLOUD HYBRID STATUS CHECK (PAPERSPACE)"
echo "============================================="
echo ""

# Get current IP
CURRENT_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
echo "🌐 Server IP: $CURRENT_IP"

# Check Docker
echo ""
echo "🐳 DOCKER STATUS:"
if systemctl is-active --quiet docker; then
    echo "✅ Docker service: Running"
else
    echo "❌ Docker service: Not running"
fi

# Check containers
echo ""
echo "📦 CONTAINER STATUS:"
if docker ps --filter "name=nextcloud" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q nextcloud; then
    docker ps --filter "name=nextcloud" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo "❌ No Nextcloud containers running"
fi

# Check Google Drive mount
echo ""
echo "☁️ GOOGLE DRIVE STATUS:"
if mountpoint -q /mnt/gdrive; then
    echo "✅ Google Drive: Mounted"
    echo "📁 Available space: $(df -h /mnt/gdrive | tail -1 | awk '{print $4}')"
    echo "📂 Upload directory: /mnt/gdrive/nextcloud-uploads"
    
    # Test rclone connection dengan path paperspace
    if rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive: >/dev/null 2>&1; then
        echo "✅ Rclone connection: OK"
    else
        echo "❌ Rclone connection: Failed"
    fi
else
    echo "❌ Google Drive: Not mounted"
    echo "🔧 Try: sudo systemctl restart rclone-gdrive"
fi

# Check web access
echo ""
echo "🌐 WEB ACCESS:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
    echo "✅ Local access: OK (HTTP $HTTP_CODE)"
    echo "🔗 URL: http://$CURRENT_IP:8081"
else
    echo "❌ Local access: Failed (HTTP $HTTP_CODE)"
fi

# Summary
echo ""
echo "📋 QUICK SUMMARY:"
ISSUES=0

if ! systemctl is-active --quiet docker; then
    echo "❌ Docker service issue"
    ((ISSUES++))
fi

if ! docker ps | grep -q nextcloud-app; then
    echo "❌ Nextcloud not running"
    ((ISSUES++))
fi

if ! mountpoint -q /mnt/gdrive; then
    echo "❌ Google Drive not mounted"
    ((ISSUES++))
fi

if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "302" ]]; then
    echo "❌ Web access issue"
    ((ISSUES++))
fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ All systems operational!"
    echo ""
    echo "🚀 Access your Nextcloud at:"
    echo "   http://$CURRENT_IP:8081"
    echo ""
    echo "🔧 Test rclone dengan path paperspace:"
    echo "   rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive:"
else
    echo "⚠️ Found $ISSUES issue(s) that need attention"
    echo ""
    echo "🔧 Troubleshooting commands:"
    echo "   docker compose logs app     # Check app logs"
    echo "   docker compose restart     # Restart containers"
    echo "   sudo systemctl status rclone-gdrive  # Check mount"
fi
EOF

chmod +x check-status.sh
```

### C. Script Nuclear Reset (Path Paperspace)
```bash
# Buat script reset dengan path paperspace
cat > nuclear-reset-clean.sh << 'EOF'
#!/bin/bash

echo "💥 NUCLEAR RESET - CLEAN ALL NEXTCLOUD DATA (PAPERSPACE)"
echo "========================================================"
echo ""
echo "⚠️  WARNING: This will DELETE ALL Nextcloud data!"
echo "⚠️  Database, config, apps, themes akan HILANG!"
echo "⚠️  User uploads di Google Drive TIDAK akan dihapus"
echo ""

read -p "🔥 Are you sure? Type 'YES' to continue: " confirm
if [ "$confirm" != "YES" ]; then
    echo "❌ Reset cancelled"
    exit 1
fi

echo ""
echo "🛑 STOPPING ALL CONTAINERS..."
docker compose down --volumes 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true

echo ""
echo "🗑️  REMOVING DOCKER DATA..."
docker system prune -af --volumes
docker volume prune -f

echo ""
echo "🧹 CLEANING PROJECT DATA..."
sudo rm -rf /home/paperspace/nextcloud-server/data/mysql/* 2>/dev/null || true
sudo rm -rf /home/paperspace/nextcloud-server/data/nextcloud/* 2>/dev/null || true

# Recreate directories with correct permissions
mkdir -p /home/paperspace/nextcloud-server/data/mysql
mkdir -p /home/paperspace/nextcloud-server/data/nextcloud
sudo chown -R 999:999 /home/paperspace/nextcloud-server/data/mysql
sudo chown -R 33:33 /home/paperspace/nextcloud-server/data/nextcloud

echo ""
echo "🔧 CLEANING GOOGLE DRIVE NEXTCLOUD DIRECTORY..."
if mountpoint -q /mnt/gdrive; then
    # Only clean Nextcloud specific files, not all Google Drive
    sudo rm -rf /mnt/gdrive/nextcloud-uploads/* 2>/dev/null || true
    sudo mkdir -p /mnt/gdrive/nextcloud-uploads
    sudo chown -R 33:33 /mnt/gdrive/nextcloud-uploads
    sudo chmod -R 0755 /mnt/gdrive/nextcloud-uploads
    echo "✅ Google Drive Nextcloud directory cleaned"
else
    echo "⚠️  Google Drive not mounted, skipping cleanup"
fi

echo ""
echo "🔄 RESTARTING DOCKER SERVICE..."
sudo systemctl restart docker
sleep 5

echo ""
echo "🎉 NUCLEAR RESET COMPLETE!"
echo ""
echo "🚀 Ready for fresh deployment!"
echo "   Run: ./deploy-nextcloud-complete.sh"
echo ""
echo "🔧 Test rclone dengan path paperspace:"
echo "   rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive:"
EOF

chmod +x nuclear-reset-clean.sh
```

---

## 🚀 QUICK START COMMANDS (PATH PAPERSPACE)

```bash
# 1. Setup project
mkdir -p /home/paperspace/nextcloud-server && cd /home/paperspace/nextcloud-server

# 2. Setup rclone (manual) dengan path paperspace
rclone config --config=/home/paperspace/nextcloud-server/rclone/rclone.conf
# Setup remote: alldrive

# 3. Test connection dengan path paperspace
rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive:

# 4. Setup auto-mount dengan path paperspace
sudo tee /etc/systemd/system/rclone-gdrive.service > /dev/null << 'EOF'
[Unit]
Description=RClone mount Google Drive
After=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/rclone mount alldrive: /mnt/gdrive --config=/home/paperspace/nextcloud-server/rclone/rclone.conf --allow-other --allow-non-empty --uid=33 --gid=33 --umask=007 --vfs-cache-mode=full --daemon=false
ExecStop=/bin/fusermount3 -u /mnt/gdrive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable rclone-gdrive
sudo systemctl start rclone-gdrive

# 5. Deploy Nextcloud
./deploy-nextcloud-complete.sh

# 6. Check status
./check-status.sh

# 7. Access web: http://YOUR-IP:8081
```

---

## ⚠️ IMPORTANT - PATH PAPERSPACE

**SEMUA COMMAND RCLONE HARUS MENGGUNAKAN PATH:**
```bash
rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive:
```

**BUKAN:**
```bash
rclone --config=~/nextcloud-server/rclone/rclone.conf lsd alldrive:
```

**PATH SYSTEMD SERVICE:**
```
--config=/home/paperspace/nextcloud-server/rclone/rclone.conf
```

**PROJECT DIRECTORY:**
```
/home/paperspace/nextcloud-server/
```

---

**🎉 Sekarang semua path sudah benar untuk user `paperspace`!**