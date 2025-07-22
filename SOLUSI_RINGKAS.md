# 🚨 SOLUSI ERROR: "Configuration was not read or initialized correctly"

## 🎯 Solusi Tercepat

### Option 1: Script Otomatis
```bash
# Download script (jika belum ada)
wget https://raw.githubusercontent.com/[repo]/fix-nextcloud-config-error.sh

# Jalankan script perbaikan
bash fix-nextcloud-config-error.sh
```

### Option 2: Manual Quick Fix
```bash
# 1. Backup dan hapus config corrupt
sudo cp /mnt/gdrive/config/config.php /mnt/gdrive/config/config.php.backup-$(date +%Y%m%d_%H%M%S)
sudo rm /mnt/gdrive/config/config.php

# 2. Fix permission
sudo chown -R 33:33 /mnt/gdrive/config /mnt/gdrive/data
sudo chmod -R 0770 /mnt/gdrive/config /mnt/gdrive/data

# 3. Restart Nextcloud
cd ~/nextcloud-server  # atau lokasi docker-compose.yml Anda
docker compose down
docker compose up -d

# 4. Akses web interface untuk fresh install
# http://YOUR_IP:8081
```

## 📋 Data untuk Fresh Install

**Saat install ulang via web interface, gunakan data ini:**

| Field | Value |
|-------|-------|
| Admin User | `admin` |
| Admin Password | `(password Anda)` |
| Data Folder | `/var/www/html/data` |
| Database Type | `MySQL/MariaDB` |
| Database Host | `db` |
| Database Name | `nextcloud` |
| Database User | `nextclouduser` |
| Database Password | `Nextcloud123!` |

## 🔧 Jika Mount Google Drive Bermasalah

```bash
# Unmount
sudo fusermount -u /mnt/gdrive

# Mount ulang (sesuaikan path config rclone)
sudo rclone mount alldrive: /mnt/gdrive \
  --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \
  --allow-other \
  --uid=33 --gid=33 \
  --umask=007 \
  --vfs-cache-mode=full &

# Buat folder jika belum ada
sudo mkdir -p /mnt/gdrive/data /mnt/gdrive/config
sudo chown -R 33:33 /mnt/gdrive/data /mnt/gdrive/config
```

## ✅ Verifikasi Setelah Perbaikan

```bash
# Cek mount
mountpoint /mnt/gdrive && echo "✅ Mount OK" || echo "❌ Mount ERROR"

# Cek container
docker ps | grep nextcloud

# Cek permission
ls -la /mnt/gdrive/config/
ls -la /mnt/gdrive/data/

# Test akses web
curl -I http://localhost:8081
```

## 🆘 Troubleshooting Lanjutan

Jika masih bermasalah, jalankan script diagnosis:
```bash
bash nextcloud-diagnose.sh
```

Atau baca panduan lengkap:
```bash
cat NEXTCLOUD_TROUBLESHOOTING.md
```

---

**🎯 TL;DR:** Error ini 99% karena permission salah atau config corrupt. Hapus config, fix permission, restart container, install ulang via web.

