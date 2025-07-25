# 🚀 NEXTCLOUD HYBRID SETUP TUTORIAL
## Database, Config, Apps, Themes → VPS | User Uploads → Google Drive

**KONSEP HYBRID:**
- 🗄️ Database: VPS (Docker volume)
- ⚙️ Config: VPS (Docker volume) 
- 📱 Apps: VPS (Docker volume)
- 🎨 Themes: VPS (Docker volume)
- 📁 **HANYA user uploads**: Google Drive

---

## 🔧 PART 1: PERSIAPAN VPS

```bash
# Update sistem
sudo apt update && sudo apt upgrade -y
sudo apt install -y git nano htop unzip curl wget ca-certificates gnupg lsb-release fuse fuse3

# Buat user (jika login sebagai root)
sudo adduser paperspace
sudo usermod -aG sudo paperspace
su - paperspace
```

---

## 🐳 PART 2: INSTALL DOCKER

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

---

## ☁️ PART 3: INSTALL & SETUP RCLONE

```bash
# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Buat project directory
mkdir -p ~/nextcloud-server
cd ~/nextcloud-server

# Buat config directory
mkdir -p rclone

# Setup rclone config
rclone config --config=~/nextcloud-server/rclone/rclone.conf
```

**Setup Google Drive:**
- `n` → nama: `alldrive` → `15` (Google Drive)
- Enter untuk default → `1` (Full access)
- `y` untuk auto config → Login Google
- `y` untuk keep → `q` untuk quit

```bash
# Test koneksi
rclone --config=~/nextcloud-server/rclone/rclone.conf lsd alldrive:
```

---

## 🗂️ PART 4: MOUNT GOOGLE DRIVE

```bash
# Buat mount point
sudo mkdir -p /mnt/gdrive

# Test mount manual
sudo rclone mount alldrive: /mnt/gdrive \
  --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \
  --allow-other --allow-non-empty \
  --uid=33 --gid=33 --umask=007 \
  --vfs-cache-mode=full --daemon

sleep 10
mountpoint /mnt/gdrive && echo "✅ Mount berhasil"
```

**Auto-mount service:**
```bash
sudo nano /etc/systemd/system/rclone-gdrive.service
```

Paste:
```ini
[Unit]
Description=RClone mount Google Drive
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/rclone mount alldrive: /mnt/gdrive --config=/home/paperspace/nextcloud-server/rclone/rclone.conf --allow-other --allow-non-empty --uid=33 --gid=33 --umask=007 --vfs-cache-mode=full --daemon=false
ExecStop=/bin/fusermount -u /mnt/gdrive
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable rclone-gdrive
sudo systemctl start rclone-gdrive
sudo systemctl status rclone-gdrive
```

---

## 🏗️ PART 5: SETUP NEXTCLOUD PROJECT

```bash
cd ~/nextcloud-server

# Download script deployment
curl -O https://raw.githubusercontent.com/user/repo/main/deploy-hybrid-stable.sh
curl -O https://raw.githubusercontent.com/user/repo/main/nuclear-reset-vps-only.sh
curl -O https://raw.githubusercontent.com/user/repo/main/force-fresh-setup.sh
curl -O https://raw.githubusercontent.com/user/repo/main/backup-to-gdrive.sh

chmod +x *.sh
```

**ATAU buat manual:**

```bash
# Buat struktur folder
mkdir -p php-config mysql-config
```

---

## 🚀 PART 6: DEPLOY NEXTCLOUD

```bash
# Jalankan deployment
./deploy-hybrid-stable.sh
```

**Jika setup wizard ter-skip:**
```bash
./force-fresh-setup.sh
```

---

## 🌐 PART 7: AKSES SETUP WIZARD

1. **Buka browser:** `http://YOUR_VPS_IP:8081`

2. **Setup wizard akan muncul dengan form:**
   - **Admin Username:** `admin`
   - **Admin Password:** `Dimas112233!`
   - **Data folder:** `/var/www/html/data` ⚠️ **JANGAN UBAH**
   - **Database:** `MySQL/MariaDB`
   - **Database host:** `db`
   - **Database name:** `nextcloud`
   - **Database user:** `nextclouduser`
   - **Database password:** `Nextcloud123!`

3. **Klik "Finish Setup"**

---

## 🔧 PART 8: SETUP DOMAIN & SSL (OPSIONAL)

```bash
# Update domain di .env
nano .env
# Ubah: DOMAIN=your-domain.com

# Setup Nginx
sudo apt install -y nginx
sudo nano /etc/nginx/sites-available/your-domain.com
```

Paste:
```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/your-domain.com /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Setup SSL
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

---

## 💾 PART 9: BACKUP SYSTEM

```bash
# Backup manual
./backup-to-gdrive.sh

# Setup auto backup (setiap hari jam 2 pagi)
crontab -e
```

Tambahkan:
```bash
0 2 * * * cd /home/paperspace/nextcloud-server && ./backup-to-gdrive.sh
```

---

## 🔄 TROUBLESHOOTING

### Setup Wizard Skip
```bash
./force-fresh-setup.sh
```

### Reset Total (Hanya VPS Data)
```bash
./nuclear-reset-vps-only.sh
./deploy-hybrid-stable.sh
```

### Masalah Google Drive Mount
```bash
sudo systemctl restart rclone-gdrive
sudo systemctl status rclone-gdrive
```

### Cek Status
```bash
docker compose ps
docker compose logs app
mountpoint /mnt/gdrive
```

---

## 📋 STRUKTUR PENYIMPANAN

```
VPS (Docker Volumes):
├── nextcloud_db          # Database MySQL
├── nextcloud_config      # Config Nextcloud
├── nextcloud_html        # Aplikasi Nextcloud
├── nextcloud_apps        # Custom apps
└── nextcloud_themes      # Themes

Google Drive:
├── nextcloud-uploads/    # User uploads dari dashboard
└── nextcloud-backups/    # Backup VPS data
```

---

## ✅ VERIFIKASI SETUP

1. **Akses dashboard:** `http://YOUR_IP:8081`
2. **Login dengan admin/Dimas112233!**
3. **Upload file test** → Cek di Google Drive
4. **Install app** → Tersimpan di VPS
5. **Ubah theme** → Tersimpan di VPS
6. **Backup test:** `./backup-to-gdrive.sh`

---

## 🎯 KEUNGGULAN HYBRID SETUP

✅ **Database cepat** (VPS SSD)  
✅ **Config aman** (VPS)  
✅ **Apps stabil** (VPS)  
✅ **Unlimited storage** (Google Drive)  
✅ **Backup mudah** (VPS data ke Google Drive)  
✅ **Performance optimal**  

---

**🎉 SETUP SELESAI!**

Nextcloud Anda sekarang menggunakan VPS untuk database/config dan Google Drive hanya untuk user uploads.