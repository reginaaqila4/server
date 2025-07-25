# 🚨 Nextcloud Error: "Configuration was not read or initialized correctly"

## Penyebab Umum Error

Error ini biasanya terjadi karena:

1. **File `config.php` corrupt atau tidak bisa dibaca**
2. **Permission salah pada folder config/data**  
3. **Google Drive mount bermasalah**
4. **Container tidak bisa akses file di mount point**

## 🛠️ Solusi Cepat (Quick Fix)

### 1. Jalankan Script Diagnostik
```bash
bash nextcloud-diagnose.sh
```

### 2. Jalankan Script Perbaikan Otomatis  
```bash
bash fix-nextcloud-config-error.sh
```

## 🔧 Manual Troubleshooting

### Step 1: Cek Status Mount Google Drive
```bash
# Cek apakah Google Drive ter-mount
sudo mountpoint /mnt/gdrive
mountpoint /mnt/gdrive && echo "✅ Mount OK" || echo "❌ Mount ERROR"

# Cek isi Google Drive
ls -la /mnt/gdrive/
```

**Jika mount bermasalah:**
```bash
# Unmount dulu jika ada
sudo fusermount -u /mnt/gdrive 2>/dev/null

# Mount ulang
sudo rclone mount alldrive: /mnt/gdrive \
  --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \
  --allow-other \
  --dir-cache-time=1000h \
  --vfs-cache-mode=full \
  --vfs-cache-max-size=5G \
  --vfs-cache-max-age=24h \
  --vfs-read-chunk-size=32M \
  --vfs-read-chunk-size-limit=2G \
  --buffer-size=32M \
  --umask=007 \
  --uid=33 \
  --gid=33 \
  --poll-interval=15s \
  --drive-chunk-size=32M \
  --timeout=1h \
  --log-level=INFO &
```

### Step 2: Cek dan Perbaiki Permission

```bash
# Cek permission saat ini
ls -la /mnt/gdrive/config/
ls -la /mnt/gdrive/data/

# Fix permission
sudo chown -R 33:33 /mnt/gdrive/config
sudo chown -R 33:33 /mnt/gdrive/data  
sudo chmod -R 0770 /mnt/gdrive/config
sudo chmod -R 0770 /mnt/gdrive/data
```

### Step 3: Backup dan Hapus Config Corrupt

```bash
# Backup config lama
sudo cp /mnt/gdrive/config/config.php /mnt/gdrive/config/config.php.backup-$(date +%Y%m%d_%H%M%S)

# Hapus config corrupt
sudo rm /mnt/gdrive/config/config.php
```

### Step 4: Restart Containers

```bash
# Masuk ke directory project
cd ~/nextcloud-server  # atau sesuai lokasi Anda

# Restart containers
docker compose down
docker compose up -d

# Cek status
docker compose ps
```

### Step 5: Fresh Installation via Web

1. **Akses Nextcloud di browser:**
   ```
   http://YOUR_SERVER_IP:8081
   ```

2. **Isi form installation:**
   - **Admin User:** `admin`
   - **Admin Password:** `(password Anda)`
   - **Data Folder:** `/var/www/html/data`
   - **Database Type:** `MySQL/MariaDB`
   - **Database Host:** `db`
   - **Database Name:** `nextcloud`
   - **Database User:** `nextclouduser`
   - **Database Password:** `Nextcloud123!`

3. **Klik "Finish Setup"**

### Step 6: Edit Trusted Domains (Opsional)

```bash
# Edit config
sudo nano /mnt/gdrive/config/config.php

# Tambahkan trusted domains
'trusted_domains' =>
array (
  0 => 'localhost',
  1 => '127.0.0.1:8081', 
  2 => 'YOUR_SERVER_IP:8081',
  3 => 'your-domain.com',
),

# Restart app container
docker compose restart app
```

## 🔍 Debugging Commands

### Cek Log Container
```bash
# Log real-time
docker compose logs -f app

# Log khusus Nextcloud
docker logs $(docker ps | grep nextcloud-.*-app | awk '{print $1}')
```

### Akses Shell Container
```bash
# Masuk ke container
docker exec -it $(docker ps | grep nextcloud-.*-app | awk '{print $1}') bash

# Cek permission dari dalam container
ls -la /var/www/html/config/
ls -la /var/www/html/data/
```

### Maintenance Commands
```bash
# Get container name
CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')

# Maintenance mode ON
docker exec -u www-data $CONTAINER php occ maintenance:mode --on

# Check config
docker exec -u www-data $CONTAINER php occ config:list system

# Repair database
docker exec -u www-data $CONTAINER php occ db:add-missing-indices

# Maintenance mode OFF  
docker exec -u www-data $CONTAINER php occ maintenance:mode --off
```

## 🆘 Jika Masih Bermasalah

### Option 1: Complete Reset
```bash
# Stop semua
docker compose down

# Hapus volume lama (HATI-HATI!)
docker volume prune -f

# Hapus config dan data
sudo rm -rf /mnt/gdrive/config/* /mnt/gdrive/data/*

# Start fresh
docker compose up -d
```

### Option 2: Rebuild Container
```bash
# Pull image terbaru
docker compose pull

# Rebuild dan start
docker compose up -d --force-recreate
```

### Option 3: Check Environment File
```bash
# Cek file .env
cat ~/nextcloud-server/.env

# Pastikan variable benar:
# TRUSTED_DOMAINS=localhost,127.0.0.1:8081,YOUR_IP
# DOMAIN=YOUR_IP
```

## 📞 Support & Logs

Jika masih bermasalah, kumpulkan informasi berikut:

```bash
# System info
uname -a
docker version
docker compose version

# Mount status
mount | grep gdrive
df -h | grep gdrive

# Container status  
docker ps -a
docker compose logs app | tail -50

# File permissions
ls -la /mnt/gdrive/config/
ls -la /mnt/gdrive/data/

# Config file (jika ada)
sudo head -20 /mnt/gdrive/config/config.php
```

## ✅ Prevention Tips

1. **Selalu backup config sebelum edit**
2. **Jangan edit file saat container running**
3. **Pastikan mount Google Drive stabil**
4. **Monitor disk space dan memory**
5. **Update container secara berkala**

---

**Scripts yang tersedia:**
- `nextcloud-diagnose.sh` - Diagnostic lengkap
- `fix-nextcloud-config-error.sh` - Perbaikan otomatis
- `nextcloud-manual-fix.sh` - Panduan manual

