#!/bin/bash

# Nextcloud Complete Backup Script
# Backs up everything: database, config, apps, themes, user settings

BACKUP_DIR="/mnt/gdrive/backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="nextcloud_complete_backup_$TIMESTAMP"
TEMP_BACKUP="/tmp/$BACKUP_NAME"

echo "🔄 Starting Complete Nextcloud Backup..."
echo "📅 Timestamp: $TIMESTAMP"

# Create backup directories
mkdir -p "$TEMP_BACKUP"
mkdir -p "$BACKUP_DIR"

# 1. Backup Database
echo "🗄️  Backing up MySQL database..."
docker exec nextcloud-server-db mysqldump -u root -pNextcloud123! --single-transaction --routines --triggers nextcloud > "$TEMP_BACKUP/database.sql"
if [ $? -eq 0 ]; then
    echo "✅ Database backup completed"
else
    echo "❌ Database backup failed"
    exit 1
fi

# 2. Backup Nextcloud Config
echo "📋 Backing up Nextcloud configuration..."
docker cp nextcloud-server-app:/var/www/html/config "$TEMP_BACKUP/config"
echo "✅ Config backup completed"

# 3. Backup Custom Apps
echo "📱 Backing up custom apps..."
docker cp nextcloud-server-app:/var/www/html/custom_apps "$TEMP_BACKUP/custom_apps" 2>/dev/null || echo "No custom apps found"

# 4. Backup Themes
echo "🎨 Backing up themes..."
docker cp nextcloud-server-app:/var/www/html/themes "$TEMP_BACKUP/themes"
echo "✅ Themes backup completed"

# 5. Create backup info file
echo "📝 Creating backup information..."
cat > "$TEMP_BACKUP/backup_info.txt" << EOF
Nextcloud Complete Backup
========================
Backup Date: $(date)
Backup Type: Complete (Database + Config + Apps + Themes)
Nextcloud Version: $(docker exec nextcloud-server-app php /var/www/html/occ -V 2>/dev/null || echo "Unknown")
Database: MySQL
Data Location: Google Drive (/mnt/gdrive/nextcloud-data)

Files Included:
- database.sql (Complete MySQL dump)
- config/ (All Nextcloud configuration)
- custom_apps/ (Custom installed apps)
- themes/ (Custom themes)

Restore Instructions:
1. Run nextcloud-restore.sh
2. Or manually restore using these files

Note: User data is stored in Google Drive and backed up separately
EOF

# 6. Create compressed archive
echo "📦 Creating compressed backup archive..."
cd /tmp
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"

# 7. Move to Google Drive
echo "☁️  Moving backup to Google Drive..."
mv "$BACKUP_NAME.tar.gz" "$BACKUP_DIR/"

# 8. Cleanup temp files
echo "🧹 Cleaning up temporary files..."
rm -rf "$TEMP_BACKUP"

# 9. Keep only last 10 backups
echo "📂 Managing backup retention (keeping last 10)..."
cd "$BACKUP_DIR"
ls -t nextcloud_complete_backup_*.tar.gz | tail -n +11 | xargs -r rm

# 10. Show backup summary
echo ""
echo "🎉 Backup completed successfully!"
echo "📁 Backup location: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "📊 Backup size: $(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)"
echo "📋 Available backups:"
ls -lah "$BACKUP_DIR"/nextcloud_complete_backup_*.tar.gz | tail -5

echo ""
echo "✅ Complete backup finished at $(date)"
echo "🔄 Next backup will be created automatically by cron"