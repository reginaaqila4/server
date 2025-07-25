# 🚀 TUTORIAL NEXTCLOUD HYBRID - LENGKAP & ANTI ERROR (FIXED)

### 📋 KONSEP SETUP:
- **Database & Config** → VPS (`/home/paperspace/nextcloud-server/data/`)
- **User uploads** → Google Drive (remote: `alldrive:`)
- **Setup wizard** muncul untuk konfigurasi admin

---

## 🔧 STEP 1: PERSIAPAN SISTEM

```bash
# Update sistem
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y curl wget git nano htop fuse3 ca-certificates gnupg lsb-release

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker paperspace
newgrp docker

# Test Docker
docker run hello-world

# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Check rclone path (PENTING!)
which rclone
# Output bisa: /usr/bin/rclone atau /usr/local/bin/rclone

# Verify installations
docker --version
rclone version
```

---

## ☁️ STEP 2: SETUP RCLONE DENGAN REMOTE 'alldrive:'

### A. Buat Directory Project
```bash
# Buat directory project
mkdir -p /home/paperspace/nextcloud-server
cd /home/paperspace/nextcloud-server

# Buat subdirectory untuk rclone
mkdir -p rclone

# Verify path
pwd
# Harus output: /home/paperspace/nextcloud-server
```

### B. Setup Rclone Config
```bash
# Setup rclone config dengan path lengkap
rclone config --config=/home/paperspace/nextcloud-server/rclone/rclone.conf

# Ikuti langkah ini:
# 1. Ketik: n (new remote)
# 2. Name: alldrive
# 3. Storage: 15 (Google Drive)
# 4. Client ID: (kosong, tekan Enter)
# 5. Client Secret: (kosong, tekan Enter)  
# 6. Scope: 1 (Full access)
# 7. Root folder: (kosong, tekan Enter)
# 8. Service account: (kosong, tekan Enter)
# 9. Auto config: y
# 10. Login ke Google Account di browser
# 11. Configure as team drive: n
# 12. Keep config: y
# 13. Quit: q
```

### C. Test Rclone Connection
```bash
# Test connection dengan path lengkap
rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive:

# Harus menampilkan folder di Google Drive Anda
# Jika error, ulangi setup config
```

---

## 🗂️ STEP 3: SETUP AUTO-MOUNT GOOGLE DRIVE (PATH RCLONE YANG BENAR!)

### A. Buat Mount Point
```bash
# Buat mount point
sudo mkdir -p /mnt/gdrive

# Set permissions
sudo chmod 755 /mnt/gdrive
```

### B. Check Path Rclone (PENTING!)
```bash
# Check dimana rclone terinstall
which rclone

# Jika output: /usr/bin/rclone → gunakan /usr/bin/rclone
# Jika output: /usr/local/bin/rclone → gunakan /usr/local/bin/rclone
```

### C. Buat Systemd Service (PATH YANG BENAR!)
```bash
# Buat systemd service file
sudo nano /etc/systemd/system/rclone-gdrive.service

# Copy paste ini ke file (GUNAKAN PATH YANG BENAR!):
[Unit]
Description=RClone mount Google Drive
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStartPre=/bin/mkdir -p /mnt/gdrive
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

# ⚠️ CATATAN: Jika `which rclone` menunjukkan /usr/local/bin/rclone
# Maka ubah ExecStart=/usr/bin/rclone menjadi ExecStart=/usr/local/bin/rclone

# Save file: Ctrl+X, Y, Enter
```

### D. Aktifkan Service
```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable auto-start
sudo systemctl enable rclone-gdrive

# Start service
sudo systemctl start rclone-gdrive

# Check status
sudo systemctl status rclone-gdrive

# Jika ada error "no such file or directory", edit path rclone:
# sudo nano /etc/systemd/system/rclone-gdrive.service
# Ubah ExecStart=/usr/local/bin/rclone menjadi ExecStart=/usr/bin/rclone
# Lalu:
# sudo systemctl daemon-reload
# sudo systemctl restart rclone-gdrive

# Verify mount
mountpoint /mnt/gdrive && echo "✅ Google Drive mounted!"

# Test access
ls -la /mnt/gdrive
```

---

## 🐳 STEP 4: SETUP NEXTCLOUD PROJECT

### A. Buat Structure Project
```bash
# Masuk ke directory project
cd /home/paperspace/nextcloud-server

# Buat semua directory yang diperlukan
mkdir -p data/mysql
mkdir -p data/nextcloud
mkdir -p php-config
mkdir -p mysql-config
mkdir -p scripts

# Verify structure
ls -la
```

### B. Buat File .env
```bash
# Buat file .env
nano .env

# Copy paste ini:
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

# Save file: Ctrl+X, Y, Enter
```

### C. Buat PHP Configuration
```bash
# 1. Upload configuration
nano php-config/uploads.ini

# Copy paste ini:
; PHP Upload Configuration - High Performance
upload_max_filesize = 50G
post_max_size = 50G
memory_limit = 1G
max_execution_time = 43200
max_input_time = 43200
max_input_vars = 20000
file_uploads = On
max_file_uploads = 1000

# Save: Ctrl+X, Y, Enter

# 2. OPcache configuration
nano php-config/opcache.ini

# Copy paste ini:
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

# Save: Ctrl+X, Y, Enter

# 3. APCu configuration
nano php-config/apcu.ini

# Copy paste ini:
; APCu Configuration - High Performance
[apcu]
apc.enabled = 1
apc.shm_size = 256M
apc.ttl = 7200
apc.gc_ttl = 3600
apc.entries_hint = 8192
apc.slam_defense = 1

# Save: Ctrl+X, Y, Enter
```

### D. Buat MySQL Configuration
```bash
# Buat MySQL config
nano mysql-config/my.cnf

# Copy paste ini:
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

# Save: Ctrl+X, Y, Enter
```

---

## 🐳 STEP 5: BUAT DOCKER COMPOSE

```bash
# Buat docker-compose.yml
nano docker-compose.yml

# Copy paste ini:
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
      # Database di VPS (TIDAK di Google Drive)
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
      # Nextcloud app dan config di VPS
      - ./data/nextcloud:/var/www/html
      # HANYA user uploads yang ke Google Drive
      - /mnt/gdrive/nextcloud-uploads:/var/www/html/data
      # PHP optimizations
      - ./php-config/uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
      - ./php-config/opcache.ini:/usr/local/etc/php/conf.d/opcache.ini
      - ./php-config/apcu.ini:/usr/local/etc/php/conf.d/apcu.ini

# Save: Ctrl+X, Y, Enter
```

---

## 🔧 STEP 6: SETUP GOOGLE DRIVE DIRECTORY

```bash
# Buat directory untuk uploads di Google Drive
sudo mkdir -p /mnt/gdrive/nextcloud-uploads

# Set permissions untuk www-data (user ID 33)
sudo chown -R 33:33 /mnt/gdrive/nextcloud-uploads
sudo chmod -R 0755 /mnt/gdrive/nextcloud-uploads

# Buat file .ncdata (penting untuk Nextcloud)
echo '# Nextcloud data directory' | sudo tee /mnt/gdrive/nextcloud-uploads/.ncdata >/dev/null
sudo chown 33:33 /mnt/gdrive/nextcloud-uploads/.ncdata
sudo chmod 660 /mnt/gdrive/nextcloud-uploads/.ncdata

# Verify setup
ls -la /mnt/gdrive/nextcloud-uploads/
```

---

## 🚀 STEP 7: DEPLOY NEXTCLOUD

### A. Pull Docker Images
```bash
# Masuk ke directory project
cd /home/paperspace/nextcloud-server

# Pull semua images
docker compose pull

# Verify images
docker images | grep -E "(nextcloud|mysql|redis)"
```

### B. Set Permissions untuk Data Directory
```bash
# Set permissions untuk data directories
sudo chown -R 999:999 ./data/mysql
sudo chown -R 33:33 ./data/nextcloud
sudo chmod -R 755 ./data/mysql
sudo chmod -R 755 ./data/nextcloud
```

### C. Start Containers Sequentially
```bash
# Stop containers jika ada yang running
docker compose down --volumes 2>/dev/null || true

# Start database first
echo "🔄 Starting database..."
docker compose up -d db

# Wait for database initialization
echo "⏳ Waiting for database to initialize..."
sleep 30

# Check database logs
docker compose logs db | tail -10

# Wait for "ready for connections" message
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

# Wait for Nextcloud to start
echo "⏳ Waiting for Nextcloud to start..."
sleep 20
```

### D. Verify Deployment
```bash
# Check container status
echo "📊 Container status:"
docker compose ps

# Check if all containers are running
docker ps | grep nextcloud

# Test web access
curl -I http://localhost:8081

# Get server IP
curl -s ifconfig.me
```

---

## 🌐 STEP 8: WEB SETUP WIZARD

### A. Access Nextcloud
```bash
# Get your server IP
echo "🌐 Your server IP: $(curl -s ifconfig.me)"
echo "🔗 Access Nextcloud at: http://$(curl -s ifconfig.me):8081"
```

### B. Setup Wizard Form
1. **Buka browser dan akses:** `http://YOUR-IP:8081`

2. **Setup wizard akan muncul dengan form:**
   - **Admin Username**: `admin` (atau sesuai keinginan)
   - **Admin Password**: `AdminPass123!` (buat password kuat)
   - **Data Folder**: `/var/www/html/data` ⚠️ **JANGAN UBAH!**
   - **Database**: `MySQL/MariaDB`
   - **Database Host**: `db`
   - **Database Name**: `nextcloud`
   - **Database User**: `nextclouduser`
   - **Database Password**: `NextcloudUser123!`

3. **Klik "Finish Setup"**

4. **Tunggu proses instalasi selesai**

---

## ✅ STEP 9: VERIFIKASI SETUP

### A. Test Upload ke Google Drive
```bash
# Check apakah setup berhasil
docker compose ps

# Check logs jika ada error
docker compose logs app | tail -20

# Test rclone connection
rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive:

# Check Google Drive mount
mountpoint /mnt/gdrive && echo "✅ Google Drive mounted"
ls -la /mnt/gdrive/nextcloud-uploads/
```

### B. Test Upload di Dashboard
1. **Login ke Nextcloud dashboard**
2. **Upload file test**
3. **Verify file masuk ke Google Drive:**
   ```bash
   ls -la /mnt/gdrive/nextcloud-uploads/
   ```

### C. Buat Script Check Status
```bash
# Buat script untuk check status
nano check-status.sh

# Copy paste ini:
#!/bin/bash

echo "📊 NEXTCLOUD STATUS CHECK"
echo "========================"
echo ""

# Get current IP
CURRENT_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
echo "🌐 Server IP: $CURRENT_IP"

# Check rclone path
RCLONE_PATH=$(which rclone)
echo "🔧 Rclone path: $RCLONE_PATH"

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
docker compose ps

# Check Google Drive mount
echo ""
echo "☁️ GOOGLE DRIVE STATUS:"
if mountpoint -q /mnt/gdrive; then
    echo "✅ Google Drive: Mounted"
    echo "📁 Available space: $(df -h /mnt/gdrive | tail -1 | awk '{print $4}')"
    echo "📂 Upload directory: /mnt/gdrive/nextcloud-uploads"
    
    # Test rclone connection
    if rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive: >/dev/null 2>&1; then
        echo "✅ Rclone connection: OK"
    else
        echo "❌ Rclone connection: Failed"
    fi
else
    echo "❌ Google Drive: Not mounted"
    echo "🔧 Try: sudo systemctl restart rclone-gdrive"
fi

# Check rclone service
echo ""
echo "🔧 RCLONE SERVICE:"
sudo systemctl status rclone-gdrive --no-pager -l

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

echo ""
echo "📋 QUICK SUMMARY:"
echo "🗄️ Database: VPS (./data/mysql)"
echo "⚙️ Config: VPS (./data/nextcloud)"  
echo "📁 User uploads: Google Drive (alldrive:)"
echo ""
echo "🔧 Test commands:"
echo "  docker compose logs app"
echo "  rclone --config=/home/paperspace/nextcloud-server/rclone/rclone.conf lsd alldrive:"

# Save: Ctrl+X, Y, Enter

# Make executable
chmod +x check-status.sh

# Run check
./check-status.sh
```

---

## 🧹 TROUBLESHOOTING

### Rclone Service Tidak Running?
```bash
# 1. Check path rclone
which rclone

# 2. Edit service file jika path salah
sudo nano /etc/systemd/system/rclone-gdrive.service

# 3. Ubah ExecStart path sesuai output `which rclone`:
# Jika which rclone = /usr/bin/rclone, gunakan:
# ExecStart=/usr/bin/rclone mount alldrive: /mnt/gdrive ...
# 
# Jika which rclone = /usr/local/bin/rclone, gunakan:
# ExecStart=/usr/local/bin/rclone mount alldrive: /mnt/gdrive ...

# 4. Reload dan restart
sudo systemctl daemon-reload
sudo systemctl restart rclone-gdrive
sudo systemctl status rclone-gdrive
```

### Setup Wizard Ter-skip?
```bash
# Stop containers
docker compose down --volumes

# Clean data
sudo rm -rf ./data/nextcloud/*
sudo rm -rf ./data/mysql/*

# Restart deployment
docker compose up -d
```

### Google Drive Tidak Mount?
```bash
# Check service logs
sudo journalctl -u rclone-gdrive -f

# Manual mount test
sudo rclone mount alldrive: /mnt/gdrive \
    --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \
    --allow-other --allow-non-empty \
    --uid=33 --gid=33 --umask=007 \
    --vfs-cache-mode=full --daemon
```

---

## 🎯 SUCCESS INDICATORS

✅ **Setup wizard muncul** saat akses pertama  
✅ **Database connection** berhasil di setup wizard  
✅ **File upload** masuk ke `/mnt/gdrive/nextcloud-uploads/`  
✅ **Dashboard** bisa diakses dengan semua fitur  
✅ **Container status** semua running  
✅ **Rclone service** active dan running  

---

## 📋 PERBAIKAN UTAMA

### ❌ KESALAHAN SEBELUMNYA:
```bash
ExecStart=/usr/local/bin/rclone mount alldrive: /mnt/gdrive ...
```

### ✅ PERBAIKAN:
```bash
# Check path dulu
which rclone

# Gunakan path yang benar:
# Jika output: /usr/bin/rclone
ExecStart=/usr/bin/rclone mount alldrive: /mnt/gdrive ...

# Jika output: /usr/local/bin/rclone  
ExecStart=/usr/local/bin/rclone mount alldrive: /mnt/gdrive ...
```

---

**🎉 Sekarang tutorial sudah diperbaiki dengan path rclone yang benar!**

**Terima kasih atas koreksinya! Sekarang semua user yang upload di dashboard akan otomatis masuk ke Google Drive dengan remote `alldrive:` tanpa error!**