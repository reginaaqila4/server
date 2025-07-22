#!/bin/bash

echo "🔧 Fixing Google Drive Mount and Nextcloud Config Error"
echo "======================================================="

# Function to unmount and clean up
cleanup_mount() {
    echo ""
    echo "🧹 Cleaning up existing mount..."
    
    # Kill any existing rclone processes
    sudo pkill -f rclone || true
    sleep 2
    
    # Force unmount
    sudo fusermount -u /mnt/gdrive 2>/dev/null || true
    sudo umount -f /mnt/gdrive 2>/dev/null || true
    sudo umount -l /mnt/gdrive 2>/dev/null || true
    
    # Wait a moment
    sleep 3
    
    # Check if still mounted
    if mountpoint -q /mnt/gdrive; then
        echo "❌ Still mounted, trying force unmount..."
        sudo fuser -km /mnt/gdrive 2>/dev/null || true
        sleep 2
        sudo fusermount -u /mnt/gdrive 2>/dev/null || true
    fi
    
    # Verify unmount
    if mountpoint -q /mnt/gdrive; then
        echo "❌ Cannot unmount /mnt/gdrive"
        echo "   Please reboot the server and try again"
        return 1
    else
        echo "✅ Successfully unmounted"
        return 0
    fi
}

# Function to remount Google Drive
remount_gdrive() {
    echo ""
    echo "☁️ Remounting Google Drive..."
    
    # Ensure directory exists
    sudo mkdir -p /mnt/gdrive
    
    # Mount with correct parameters
    echo "🚀 Starting rclone mount..."
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
    
    # Wait for mount
    echo "⏳ Waiting for mount to complete..."
    sleep 10
    
    # Verify mount
    if mountpoint -q /mnt/gdrive; then
        echo "✅ Google Drive mounted successfully"
        echo "📂 Contents:"
        ls -la /mnt/gdrive/ | head -10
        return 0
    else
        echo "❌ Mount failed"
        return 1
    fi
}

# Function to setup directories and permissions
setup_directories() {
    echo ""
    echo "📁 Setting up directories and permissions..."
    
    # Create required directories
    sudo mkdir -p /mnt/gdrive/data
    sudo mkdir -p /mnt/gdrive/config
    
    # Set ownership and permissions
    sudo chown -R 33:33 /mnt/gdrive/data
    sudo chown -R 33:33 /mnt/gdrive/config
    sudo chmod -R 0770 /mnt/gdrive/data
    sudo chmod -R 0770 /mnt/gdrive/config
    
    echo "✅ Directories configured"
    echo "   Data: $(ls -ld /mnt/gdrive/data | awk '{print $1, $3, $4}')"
    echo "   Config: $(ls -ld /mnt/gdrive/config | awk '{print $1, $3, $4}')"
}

# Function to fix Nextcloud config
fix_nextcloud_config() {
    echo ""
    echo "🔧 Fixing Nextcloud configuration..."
    
    # Remove corrupt config if exists
    if [ -f "/mnt/gdrive/config/config.php" ]; then
        echo "🗂️ Backing up existing config..."
        sudo cp /mnt/gdrive/config/config.php /mnt/gdrive/config/config.php.backup-$(date +%Y%m%d_%H%M%S)
        
        # Check if config is corrupt (too small)
        CONFIG_SIZE=$(stat -c %s /mnt/gdrive/config/config.php)
        if [ "$CONFIG_SIZE" -lt 500 ]; then
            echo "⚠️ Config file too small ($CONFIG_SIZE bytes), removing..."
            sudo rm /mnt/gdrive/config/config.php
        else
            echo "📝 Config file seems OK ($CONFIG_SIZE bytes)"
        fi
    fi
    
    # Fix permissions on config directory
    sudo chown -R 33:33 /mnt/gdrive/config
    sudo chmod -R 0770 /mnt/gdrive/config
}

# Function to restart Nextcloud containers
restart_nextcloud() {
    echo ""
    echo "🔄 Restarting Nextcloud containers..."
    
    # Navigate to project directory
    cd /home/paperspace/nextcloud-server
    
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
}

# Function to show access information
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
    echo "📝 Fresh Installation Data:"
    echo "=========================="
    echo "Admin User: admin"
    echo "Admin Password: (your choice)"
    echo "Data Folder: /var/www/html/data"
    echo "Database Type: MySQL/MariaDB"
    echo "Database Host: db"
    echo "Database Name: nextcloud"
    echo "Database User: nextclouduser"
    echo "Database Password: Nextcloud123!"
}

# Main execution
main() {
    echo "Starting complete fix process..."
    echo ""
    
    if cleanup_mount; then
        if remount_gdrive; then
            setup_directories
            fix_nextcloud_config
            restart_nextcloud
            show_access_info
            
            echo ""
            echo "🎉 Fix completed successfully!"
            echo ""
            echo "📌 Next Steps:"
            echo "1. Open browser and go to Nextcloud URL above"
            echo "2. Do fresh installation with the data provided"
            echo "3. After installation, check if everything works"
            echo ""
            echo "🔍 If still having issues:"
            echo "- Check logs: docker compose logs -f app"
            echo "- Verify mount: ls -la /mnt/gdrive/"
            echo "- Check permissions: ls -la /mnt/gdrive/config/"
            
        else
            echo "❌ Failed to mount Google Drive"
            echo "   Please check your rclone configuration"
        fi
    else
        echo "❌ Failed to cleanup existing mount"
        echo "   Please reboot the server and try again"
    fi
}

# Run main function
main "$@"
