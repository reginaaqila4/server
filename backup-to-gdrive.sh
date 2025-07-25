#!/bin/bash

echo "💾 BACKUP NEXTCLOUD VPS DATA TO GOOGLE DRIVE"
echo "📁 Backup semua data VPS: database, config, apps, themes"
echo "📁 User uploads sudah ada di Google Drive, tidak perlu di-backup"
echo ""

# Cek Google Drive mount
if ! mountpoint -q /mnt/gdrive; then
    echo "❌ Google Drive tidak ter-mount!"
    exit 1
fi

# Buat direktori backup dengan timestamp
BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/mnt/gdrive/nextcloud-backups/backup_$BACKUP_DATE"
LOCAL_BACKUP_DIR="/tmp/nextcloud_backup_$BACKUP_DATE"

echo "📅 Backup date: $BACKUP_DATE"
echo "📁 Backup location: $BACKUP_DIR"

# Buat direktori backup
mkdir -p "$LOCAL_BACKUP_DIR"
sudo mkdir -p "$BACKUP_DIR"

echo ""
echo "🗄️  STEP 1: BACKUP DATABASE"
echo "🔄 Dumping MySQL database..."

# Backup database
docker exec nextcloud-hybrid-db mysqldump -u root -pNextcloud123! nextcloud > "$LOCAL_BACKUP_DIR/database.sql"

if [ $? -eq 0 ]; then
    echo "✅ Database backup created"
else
    echo "❌ Database backup failed!"
    exit 1
fi

echo ""
echo "⚙️  STEP 2: BACKUP DOCKER VOLUMES"

# Backup config volume
echo "🔄 Backing up config volume..."
docker run --rm -v nextcloud-hybrid_nextcloud_config:/source -v "$LOCAL_BACKUP_DIR:/backup" alpine tar czf /backup/config.tar.gz -C /source .

# Backup html volume
echo "🔄 Backing up html volume..."
docker run --rm -v nextcloud-hybrid_nextcloud_html:/source -v "$LOCAL_BACKUP_DIR:/backup" alpine tar czf /backup/html.tar.gz -C /source .

# Backup apps volume
echo "🔄 Backing up apps volume..."
docker run --rm -v nextcloud-hybrid_nextcloud_apps:/source -v "$LOCAL_BACKUP_DIR:/backup" alpine tar czf /backup/apps.tar.gz -C /source .

# Backup themes volume
echo "🔄 Backing up themes volume..."
docker run --rm -v nextcloud-hybrid_nextcloud_themes:/source -v "$LOCAL_BACKUP_DIR:/backup" alpine tar czf /backup/themes.tar.gz -C /source .

echo "✅ Docker volumes backup completed"

echo ""
echo "🐳 STEP 3: BACKUP DOCKER COMPOSE & CONFIGS"

# Backup project files
cp docker-compose.yml "$LOCAL_BACKUP_DIR/"
cp .env "$LOCAL_BACKUP_DIR/"
cp -r php-config "$LOCAL_BACKUP_DIR/"
cp -r mysql-config "$LOCAL_BACKUP_DIR/"
cp -r rclone "$LOCAL_BACKUP_DIR/"

echo "✅ Project files backup completed"

echo ""
echo "📝 STEP 4: CREATE BACKUP INFO"

cat > "$LOCAL_BACKUP_DIR/backup_info.txt" << EOF
Nextcloud VPS Backup Information
================================
Backup Date: $(date)
Backup Type: VPS Data Only (Hybrid Setup)
Server IP: $(curl -s ifconfig.me)
Nextcloud Version: $(docker exec nextcloud-hybrid-app cat /var/www/html/version.php | grep version | cut -d"'" -f4)

Contents:
- database.sql: Full MySQL database dump
- config.tar.gz: Nextcloud config volume
- html.tar.gz: Nextcloud application volume  
- apps.tar.gz: Custom apps volume
- themes.tar.gz: Themes volume
- docker-compose.yml: Docker configuration
- .env: Environment variables
- php-config/: PHP configuration files
- mysql-config/: MySQL configuration files
- rclone/: Rclone configuration

Note: User uploads are already stored in Google Drive (/mnt/gdrive/nextcloud-uploads)
and are not included in this backup.

Restore Instructions:
1. Run nuclear-reset-vps-only.sh
2. Copy backup files back to project directory
3. Run deploy-hybrid-stable.sh
4. Restore database: docker exec -i nextcloud-hybrid-db mysql -u root -pNextcloud123! nextcloud < database.sql
5. Restart containers: docker compose restart
EOF

echo "✅ Backup info created"

echo ""
echo "☁️  STEP 5: UPLOAD TO GOOGLE DRIVE"
echo "🔄 Copying backup to Google Drive..."

# Copy to Google Drive
sudo cp -r "$LOCAL_BACKUP_DIR"/* "$BACKUP_DIR/"
sudo chown -R 33:33 "$BACKUP_DIR"

# Cleanup local backup
rm -rf "$LOCAL_BACKUP_DIR"

echo "✅ Backup uploaded to Google Drive"

echo ""
echo "🎉 BACKUP COMPLETED SUCCESSFULLY!"
echo ""
echo "📋 Backup Summary:"
echo "   📁 Location: $BACKUP_DIR"
echo "   🗄️  Database: ✓ Included"
echo "   ⚙️  Config: ✓ Included"
echo "   📱 Apps: ✓ Included"
echo "   🎨 Themes: ✓ Included"
echo "   🐳 Docker files: ✓ Included"
echo "   📁 User uploads: ✓ Already in Google Drive"
echo ""
echo "📋 Backup Contents:"
ls -la "$BACKUP_DIR"

echo ""
echo "🔄 To restore this backup:"
echo "1. ./nuclear-reset-vps-only.sh"
echo "2. Copy files from: $BACKUP_DIR"
echo "3. ./deploy-hybrid-stable.sh"
echo "4. Restore database from backup"