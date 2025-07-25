# 📁 NEXTCLOUD + GOOGLE DRIVE EXTERNAL STORAGE

## Konsep Yang Anda Inginkan:
✅ **Nextcloud normal di VPS** (config, database, sistem)
✅ **Upload storage bisa pilih:** Local VPS atau Google Drive
✅ **Tidak ada masalah mount atau config**
✅ **Stabil dan mudah maintain**

## 🛠️ Setup Langkah Demi Langkah:

### Step 1: Setup Nextcloud Stabil (Local Storage)
```bash
cd ~
mkdir -p ~/nextcloud-stable
cd ~/nextcloud-stable

cat > docker-compose.yml << 'EOF'
services:
  db:
    image: mysql:8.0.36-debian
    container_name: nextcloud-stable-db
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - nextcloud_db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=Nextcloud123!
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextclouduser
      - MYSQL_PASSWORD=Nextcloud123!

  app:
    image: nextcloud:apache
    container_name: nextcloud-stable-app
    restart: always
    ports:
      - "8081:80"
    depends_on:
      - db
    volumes:
      - nextcloud_html:/var/www/html
    environment:
      - MYSQL_HOST=db
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextclouduser
      - MYSQL_PASSWORD=Nextcloud123!
      - NEXTCLOUD_TRUSTED_DOMAINS=localhost,127.0.0.1:8081,184.105.238.243,184.105.238.243:8081

volumes:
  nextcloud_db:
  nextcloud_html:
