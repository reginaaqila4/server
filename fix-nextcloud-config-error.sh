#!/bin/bash

echo "🚨 Fix: Configuration was not read or initialized correctly"
echo "=========================================================="
echo ""
echo "Error ini biasanya terjadi karena:"
echo "1. File config.php corrupt atau permission salah"
echo "2. Mount Google Drive bermasalah"  
echo "3. Container tidak bisa akses file config"
echo ""

# Function to show current status
show_status() {
    echo "📊 Current Status:"
    echo "=================="
    
    # Check mount
    if mountpoint -q /mnt/gdrive 2>/dev/null; then
        echo "✅ Google Drive mounted"
    else
        echo "❌ Google Drive NOT mounted"
        return 1
    fi
    
    # Check config file
    if [ -f "/mnt/gdrive/config/config.php" ]; then
        FILE_SIZE=$(stat -c %s /mnt/gdrive/config/config.php)
        FILE_OWNER=$(stat -c '%U:%G' /mnt/gdrive/config/config.php 2>/dev/null || echo "unknown:unknown")
        FILE_PERMS=$(stat -c '%a' /mnt/gdrive/config/config.php 2>/dev/null || echo "unknown")
        
        echo "📝 Config file: EXISTS"
        echo "   Size: $FILE_SIZE bytes"
        echo "   Owner: $FILE_OWNER" 
        echo "   Permissions: $FILE_PERMS"
        
        if [ "$FILE_SIZE" -lt 500 ]; then
            echo "   ⚠️  WARNING: File too small (possibly corrupt)"
        fi
    else
        echo "❌ Config file: NOT EXISTS"
    fi
    
    # Check containers
    if command -v docker >/dev/null 2>&1; then
        RUNNING_CONTAINERS=$(docker ps | grep nextcloud | wc -l)
        echo "🐳 Running Nextcloud containers: $RUNNING_CONTAINERS"
        
        if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
            docker ps | grep -E "(nextcloud|redis|mysql|db)" | awk '{print "   " $1 " - " $2}'
        fi
    else
        echo "❌ Docker not available"
    fi
}

# Function to backup and remove corrupt config
backup_and_remove_config() {
    echo ""
    echo "🗂️  Backing up and removing config..."
    
    if [ -f "/mnt/gdrive/config/config.php" ]; then
        BACKUP_NAME="config.php.backup-$(date +%Y%m%d_%H%M%S)"
        sudo cp /mnt/gdrive/config/config.php "/mnt/gdrive/config/$BACKUP_NAME"
        echo "✅ Backup created: $BACKUP_NAME"
        
        sudo rm /mnt/gdrive/config/config.php
        echo "✅ Corrupt config removed"
    else
        echo "ℹ️  No config file to remove"
    fi
}

# Function to fix permissions
fix_permissions() {
    echo ""
    echo "🔧 Fixing permissions..."
    
    sudo chown -R 33:33 /mnt/gdrive/config
    sudo chown -R 33:33 /mnt/gdrive/data
    sudo chmod -R 0770 /mnt/gdrive/config
    sudo chmod -R 0770 /mnt/gdrive/data
    
    echo "✅ Permissions fixed"
    echo "   Config: $(stat -c '%U:%G %a' /mnt/gdrive/config)"
    echo "   Data: $(stat -c '%U:%G %a' /mnt/gdrive/data)"
}

# Function to restart Nextcloud
restart_nextcloud() {
    echo ""
    echo "🔄 Restarting Nextcloud..."
    
    # Find the docker-compose.yml
    COMPOSE_FILE=$(find /home -name "docker-compose.yml" 2>/dev/null | grep -i nextcloud | head -1)
    
    if [ -z "$COMPOSE_FILE" ]; then
        # Try common locations
        for DIR in ~/nextcloud-server /home/paperspace/nextcloud-server; do
            if [ -f "$DIR/docker-compose.yml" ]; then
                COMPOSE_FILE="$DIR/docker-compose.yml"
                break
            fi
        done
    fi
    
    if [ -n "$COMPOSE_FILE" ]; then
        COMPOSE_DIR=$(dirname "$COMPOSE_FILE")
        echo "✅ Found compose file: $COMPOSE_FILE"
        
        cd "$COMPOSE_DIR"
        
        echo "🛑 Stopping containers..."
        docker compose down
        
        echo "⏳ Waiting 5 seconds..."
        sleep 5
        
        echo "🚀 Starting containers..."
        docker compose up -d
        
        echo "⏳ Waiting 15 seconds for startup..."
        sleep 15
        
        echo "📊 Container status:"
        docker compose ps
        
    else
        echo "❌ Docker compose file not found!"
        echo "   Please navigate to your nextcloud directory and run:"
        echo "   docker compose down && docker compose up -d"
    fi
}

# Function to show access instructions
show_access_info() {
    echo ""
    echo "🌐 Access Information:"
    echo "====================="
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # Get Nextcloud port
    NEXTCLOUD_PORT=$(docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null | grep nextcloud | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2 | head -1)
    
    if [ -n "$NEXTCLOUD_PORT" ]; then
        echo "🔗 Nextcloud URL: http://$SERVER_IP:$NEXTCLOUD_PORT"
    else
        echo "🔗 Nextcloud URL: http://$SERVER_IP:8081 (default)"
    fi
    
    echo ""
    echo "📝 Setup Information:"
    echo "   Admin User: admin"
    echo "   Admin Password: (your password)"
    echo "   Data Folder: /var/www/html/data"
    echo "   Database Type: MySQL/MariaDB"
    echo "   Database Host: db"
    echo "   Database Name: nextcloud"
    echo "   Database User: nextclouduser"  
    echo "   Database Password: Nextcloud123!"
}

# Main execution
main() {
    echo "Starting fix process..."
    echo ""
    
    show_status
    
    echo ""
    read -p "🤔 Apakah Anda ingin melanjutkan perbaikan? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        backup_and_remove_config
        fix_permissions
        restart_nextcloud
        show_access_info
        
        echo ""
        echo "🎉 Perbaikan selesai!"
        echo ""
        echo "📌 Langkah selanjutnya:"
        echo "1. Buka browser dan akses URL Nextcloud"
        echo "2. Lakukan fresh installation dengan data di atas"
        echo "3. Setelah selesai, edit trusted domains jika diperlukan"
        echo ""
        echo "🔍 Jika masih bermasalah, jalankan: bash nextcloud-diagnose.sh"
        
    else
        echo "❌ Perbaikan dibatalkan"
        echo ""
        echo "💡 Untuk diagnosis manual, jalankan: bash nextcloud-diagnose.sh"
    fi
}

# Run main function
main "$@"
