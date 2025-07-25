# 🔗 RECONNECT NEXTCLOUD KE GOOGLE DRIVE

## Masalah Saat Ini:
- ✅ Nextcloud berjalan normal di local storage
- ❌ Tidak sync otomatis ke Google Drive
- ❌ File/folder baru tidak muncul di Google Drive

## 🎯 SOLUSI TERCEPAT (Copy & Paste di Server):

### Step 1: Cek Status Google Drive Mount
```bash
# Cek apakah Google Drive masih ter-mount
sudo mountpoint /mnt/gdrive
ls -la /mnt/gdrive/

# Jika tidak ter-mount, mount ulang:
sudo rclone mount alldrive: /mnt/gdrive \
  --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \
  --allow-other --allow-non-empty \
  --uid=33 --gid=33 --umask=007 \
  --vfs-cache-mode=full --daemon
```

### Step 2: Backup dan Update Docker Compose
```bash
cd ~/nextcloud-server

# Backup current
cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d_%H%M%S)

# Update compose untuk reconnect Google Drive
cat > docker-compose.yml << 'COMPOSE_EOF'
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
COMPOSE_EOF
```

### Step 3: Prepare Google Drive Data Directory
```bash
# Buat folder data di Google Drive jika belum ada
sudo mkdir -p /mnt/gdrive/data

# Copy data existing dari local ke Google Drive
sudo cp -r /var/lib/docker/volumes/nextcloud-server_nextcloud_html/_data/data/* /mnt/gdrive/data/ 2>/dev/null || true

# Fix permissions
sudo chown -R 33:33 /mnt/gdrive/data
sudo chmod -R 0770 /mnt/gdrive/data
```

### Step 4: Restart dengan Google Drive
```bash
# Stop containers
docker compose down

# Start dengan konfigurasi baru
docker compose up -d

# Wait for startup
sleep 20

# Check status
docker compose ps
```

### Step 5: Verifikasi
```bash
# Cek apakah data ter-mount ke Google Drive
ls -la /mnt/gdrive/data/

# Test buat file via Nextcloud web interface
# File seharusnya muncul di /mnt/gdrive/data/
```

## 🎉 HASIL YANG DIHARAPKAN:

✅ **File/folder baru di Nextcloud** → Otomatis sync ke Google Drive
✅ **Data tersimpan di:** `/mnt/gdrive/data/`
✅ **Config tetap stabil** di local Docker volume
✅ **Backup otomatis** ke Google Drive

## 🔍 TROUBLESHOOTING:

### Jika mount Google Drive bermasalah:
```bash
# Unmount dan mount ulang
sudo fusermount -u /mnt/gdrive
sudo rclone mount alldrive: /mnt/gdrive \
  --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \
  --allow-other --allow-non-empty \
  --uid=33 --gid=33 --umask=007 \
  --vfs-cache-mode=full --daemon

# Tunggu 10 detik lalu restart Nextcloud
sleep 10
docker compose restart app
```

### Jika permission error:
```bash
sudo chown -R 33:33 /mnt/gdrive/data
sudo chmod -R 0770 /mnt/gdrive/data
docker compose restart app
```

## 💡 TIPS:

1. **Selalu pastikan Google Drive ter-mount** sebelum start Nextcloud
2. **Monitor space Google Drive** untuk menghindari quota limit
3. **Backup config secara berkala** 
4. **Test sync dengan upload file kecil** terlebih dahulu

---

**Setelah langkah ini, Nextcloud akan kembali sync otomatis ke Google Drive seperti setup awal Anda!** 🎯

