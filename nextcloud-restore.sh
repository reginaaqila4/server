#!/bin/bash

echo "🔄 NEXTCLOUD COMPLETE RESTORE SCRIPT"
echo "===================================="
echo "Restore: Database, Config, Apps, Themes, User Data"
echo "Source: Google Drive /backup folder"
echo ""

# Function to list available backups
list_backups() {
    echo "📋 Available backups in Google Drive:"
    echo "====================================="
    
    if [ -d "/mnt/gdrive/backup" ]; then
        ls -la /mnt/gdrive/backup/nextcloud-complete-backup-*.tar.gz 2>/dev/null | \
        awk '{print NR ". " $9 " (" $5 " bytes) - " $6 " " $7 " " $8}' | \
        sed 's|/mnt/gdrive/backup/||g'
    else
        echo "❌ No backup directory found in Google Drive"
        exit 1
    fi
}

# Function to restore from backup
restore_backup() {
    local backup_file="$1"
    local restore_dir="/tmp/nextcloud-restore-$(date +%Y%m%d_%H%M%S)"
    
    echo ""
    echo "🔄 Restoring from: $backup_file"
    echo "================================"
    
    # Extract backup
    echo "📦 Extracting backup archive..."
    mkdir -p "$restore_dir"
    cd /tmp
    cp "/mnt/gdrive/backup/$backup_file" .
    tar -xzf "$backup_file" -C "$restore_dir" --strip-components=1
    
    if [ $? -eq 0 ]; then
        echo "✅ Backup extracted successfully"
    else
        echo "❌ Failed to extract backup"
        exit 1
    fi
    
    # Stop containers for restore
    echo ""
    echo "🛑 Stopping Nextcloud containers..."
    cd ~/nextcloud-server
    docker compose down
    
    # Restore database
    echo ""
    echo "🗄️ Restoring database..."
    docker compose up -d db
    sleep 10
    
    source .env
    docker exec -i nextcloud-server-db mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" < "$restore_dir/database.sql"
    
    if [ $? -eq 0 ]; then
        echo "✅ Database restored successfully"
    else
        echo "❌ Database restore failed"
    fi
    
    # Start all containers
    echo ""
    echo "🚀 Starting all containers..."
    docker compose up -d
    sleep 20
    
    # Restore Nextcloud config
    echo ""
    echo "⚙️ Restoring Nextcloud configuration..."
    if [ -d "$restore_dir/nextcloud-config" ]; then
        docker cp "$restore_dir/nextcloud-config/config/" nextcloud-server-app:/var/www/html/
        echo "✅ Configuration restored"
    fi
    
    # Restore apps
    echo ""
    echo "📱 Restoring apps..."
    if [ -d "$restore_dir/apps" ]; then
        docker cp "$restore_dir/apps/custom_apps/" nextcloud-server-app:/var/www/html/ 2>/dev/null || true
        echo "✅ Apps restored"
    fi
    
    # Restore themes
    echo ""
    echo "🎨 Restoring themes..."
    if [ -d "$restore_dir/themes" ]; then
        docker cp "$restore_dir/themes/themes/" nextcloud-server-app:/var/www/html/ 2>/dev/null || true
        echo "✅ Themes restored"
    fi
    
    # Fix permissions
    echo ""
    echo "🔒 Fixing permissions..."
    docker exec -u root nextcloud-server-app chown -R www-data:www-data /var/www/html/
    docker exec -u root nextcloud-server-app chmod -R 755 /var/www/html/
    
    # Run Nextcloud maintenance
    echo ""
    echo "🔧 Running Nextcloud maintenance..."
    sleep 10
    docker exec -u www-data nextcloud-server-app php occ maintenance:mode --off
    docker exec -u www-data nextcloud-server-app php occ db:add-missing-indices
    docker exec -u www-data nextcloud-server-app php occ files:scan --all
    
    # Cleanup
    rm -rf "$restore_dir"
    rm -f "/tmp/$backup_file"
    
    echo ""
    echo "🎉 Restore completed successfully!"
    echo "   Access: http://47.236.62.121:8081"
}

# Main function
main() {
    if ! mountpoint -q /mnt/gdrive; then
        echo "❌ Google Drive not mounted"
        exit 1
    fi
    
    list_backups
    
    echo ""
    read -p "Enter backup number to restore (or 'q' to quit): " choice
    
    if [ "$choice" = "q" ]; then
        echo "Restore cancelled"
        exit 0
    fi
    
    backup_file=$(ls /mnt/gdrive/backup/nextcloud-complete-backup-*.tar.gz 2>/dev/null | sed -n "${choice}p" | xargs basename)
    
    if [ -z "$backup_file" ]; then
        echo "❌ Invalid backup selection"
        exit 1
    fi
    
    echo ""
    echo "⚠️  WARNING: This will replace current Nextcloud installation!"
    read -p "Continue with restore? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        restore_backup "$backup_file"
    else
        echo "Restore cancelled"
    fi
}

main "$@"

