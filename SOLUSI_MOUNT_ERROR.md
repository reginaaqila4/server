# 🚨 SOLUSI: Mount Error + Nextcloud Config Error

## Problem yang Anda alami:

1. **Google Drive sudah ter-mount tapi bermasalah** → Error "directory already mounted"
2. **Nextcloud config error** → "Configuration was not read or initialized correctly"

## 🛠️ SOLUSI LENGKAP:

### Step 1: Cleanup Mount yang Bermasalah

```bash
# Kill semua proses rclone
sudo pkill -f rclone

# Force unmount
sudo fusermount -u /mnt/gdrive
sudo umount -f /mnt/gdrive

# Jika masih error, force kill
sudo fuser -km /mnt/gdrive
sudo fusermount -u /mnt/gdrive

# Verifikasi unmount
mountpoint /mnt/gdrive && echo "❌ Still mounted" || echo "✅ Unmounted"
```

### Step 2: Mount Ulang dengan Parameter yang Benar

```bash
# Mount dengan --allow-non-empty flag
sudo rclone mount alldrive: /mnt/gdrive \
  --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \
  --allow-other \
  --allow-non-empty \
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
  --log-level=INFO \
  --daemon

# Tunggu dan cek
sleep 10
mountpoint /mnt/gdrive && echo "✅ Mount OK" || echo "❌ Mount failed"
ls -la /mnt/gdrive/
```

### Step 3: Setup Folder dan Permission

```bash
# Buat folder jika belum ada
sudo mkdir -p /mnt/gdrive/data /mnt/gdrive/config

# Fix ownership dan permission
sudo chown -R 33:33 /mnt/gdrive/data /mnt/gdrive/config
sudo chmod -R 0770 /mnt/gdrive/data /mnt/gdrive/config

# Verifikasi
ls -la /mnt/gdrive/
```

### Step 4: Hapus Config yang Corrupt

```bash
# Backup config lama (jika ada)
if [ -f "/mnt/gdrive/config/config.php" ]; then
    sudo cp /mnt/gdrive/config/config.php /mnt/gdrive/config/config.php.backup-$(date +%Y%m%d_%H%M%S)
    sudo rm /mnt/gdrive/config/config.php
    echo "✅ Config removed"
fi
```

### Step 5: Restart Nextcloud Containers

```bash
cd ~/nextcloud-server

# Stop containers
docker compose down

# Start ulang
docker compose up -d

# Tunggu startup
sleep 15

# Cek status
docker compose ps
```

### Step 6: Fresh Install via Web

1. **Buka browser:** `http://YOUR_IP:8081`
2. **Install ulang dengan data:**
   - Admin User: `admin`
   - Admin Password: `(password pilihan Anda)`
   - Data Folder: `/var/www/html/data`
   - Database Host: `db`
   - Database Name: `nextcloud`
   - Database User: `nextclouduser`
   - Database Password: `Nextcloud123!`

## 🚀 ATAU GUNAKAN SCRIPT OTOMATIS:

```bash
# Download script fix lengkap
wget https://raw.githubusercontent.com/[repo]/fix-mount-and-nextcloud.sh

# Jalankan script
bash fix-mount-and-nextcloud.sh
```

## 🔍 Debugging Commands:

```bash
# Cek mount status
mountpoint /mnt/gdrive
mount | grep gdrive

# Cek permission
ls -la /mnt/gdrive/config/
ls -la /mnt/gdrive/data/

# Cek container logs
docker compose logs -f app

# Cek proses rclone
ps aux | grep rclone
```

## ⚠️ Catatan Penting:

1. **Flag `--allow-non-empty`** diperlukan karena directory sudah ada mount sebelumnya
2. **`--daemon`** flag membuat rclone berjalan di background
3. **Selalu backup config.php** sebelum menghapus
4. **Jangan mount dengan `&`** di akhir command, gunakan `--daemon` instead

## 🆘 Jika Masih Error:

1. **Reboot server** untuk cleanup semua mount
2. **Cek rclone config:** `rclone --config=/path/to/rclone.conf lsd alldrive:`
3. **Cek disk space:** `df -h`
4. **Cek memory:** `free -h`

