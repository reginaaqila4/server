#!/bin/bash

echo "🔗 RECONNECT NEXTCLOUD TO GOOGLE DRIVE"
echo "======================================"
echo ""

# Function to check current setup
check_current_setup() {
    echo "📊 Current Setup Analysis:"
    echo "========================="
    
    # Check if Google Drive is still mounted
    if mountpoint -q /mnt/gdrive; then
        echo "✅ Google Drive mount: ACTIVE"
        echo "📁 Google Drive contents:"
        ls -la /mnt/gdrive/ | head -10
        
        # Check if old data exists
        if [ -d "/mnt/gdrive/data" ]; then
            echo ""
            echo "📂 Old Nextcloud data found in Google Drive:"
            ls -la /mnt/gdrive/data/ | head -5
        fi
    else
        echo "❌ Google Drive mount: NOT ACTIVE"
    fi
    
    # Check current Nextcloud data location
    CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    if [ -n "$CONTAINER" ]; then
        echo ""
        echo "📁 Current Nextcloud data location:"
        docker exec "$CONTAINER" ls -la /var/www/html/data/ | head -5
    fi
}

# Function to setup external storage method
setup_external_storage() {
    echo ""
    echo "🔧 SETUP EXTERNAL STORAGE METHOD"
    echo "================================"
    
    echo "Metode 1: Via Web Interface (Recommended)"
    echo "========================================="
    echo ""
    echo "1. Login ke Nextcloud: http://184.105.238.243:8081"
    echo "2. Klik profile icon (kanan atas) → Apps"
    echo "3. Cari dan install 'External storage support'"
    echo "4. Setelah install, ke Settings → Administration → External storages"
    echo "5. Add storage → Google Drive"
    echo "6. Masukkan Client ID dan Secret dari Google Cloud Console"
    echo ""
    
    echo "Metode 2: Direct Mount (Advanced)"
    echo "================================="
    echo ""
    echo "Mengganti data directory Nextcloud ke Google Drive mount"
    echo "PERINGATAN: Ini akan merubah konfigurasi existing"
}

# Function to migrate existing data
migrate_data() {
    echo ""
    echo "📦 DATA MIGRATION OPTIONS"
    echo "========================="
    
    echo "Option A: Copy from Google Drive to Nextcloud"
    echo "============================================="
    echo "cp -r /mnt/gdrive/data/admin/* /var/lib/docker/volumes/nextcloud-server_nextcloud_html/_data/data/admin/"
    echo ""
    
    echo "Option B: Replace Nextcloud data with Google Drive"
    echo "=================================================="
    echo "1. Stop containers"
    echo "2. Update docker-compose.yml"
    echo "3. Mount Google Drive to data directory"
    echo ""
    
    echo "Option C: Sync both ways"
    echo "======================="
    echo "Setup rclone sync between local and Google Drive"
}

# Function to create direct mount solution
create_direct_mount() {
    echo ""
    echo "🔄 DIRECT MOUNT SOLUTION"
    echo "======================="
    
    read -p "🤔 Ganti data directory ke Google Drive mount? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📝 Updating docker-compose.yml..."
        
        # Backup current compose
        cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d_%H%M%S)
        
        # Create new compose with Google Drive data mount
        cat > docker-compose-gdrive.yml << 'DOCKER_EOF'
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
DOCKER_EOF

        echo "✅ New compose file created with Google Drive data mount"
        
        # Apply changes
        echo "🔄 Applying changes..."
        docker compose down
        cp docker-compose-gdrive.yml docker-compose.yml
        
        # Fix permissions on Google Drive
        sudo chown -R 33:33 /mnt/gdrive/data
        sudo chmod -R 0770 /mnt/gdrive/data
        
        docker compose up -d
        
        echo "⏳ Waiting 20 seconds..."
        sleep 20
        
        echo "✅ Nextcloud now using Google Drive for data storage!"
        echo "🔗 Access: http://184.105.238.243:8081"
        
    else
        echo "❌ Direct mount cancelled"
    fi
}

# Function to setup Google Drive external storage via CLI
setup_gdrive_external() {
    echo ""
    echo "🔧 SETUP GOOGLE DRIVE EXTERNAL STORAGE"
    echo "======================================"
    
    CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    
    if [ -n "$CONTAINER" ]; then
        echo "📦 Installing External Storage app..."
        docker exec -u www-data "$CONTAINER" php occ app:install files_external
        docker exec -u www-data "$CONTAINER" php occ app:enable files_external
        
        echo "✅ External Storage app installed"
        echo ""
        echo "📋 Next steps:"
        echo "1. Go to Settings → Administration → External storages"
        echo "2. Add new storage: Google Drive"
        echo "3. Configure with your Google credentials"
        echo "4. Mount point: /GoogleDrive"
        
    else
        echo "❌ No container found"
    fi
}

# Function to show manual sync commands
show_sync_commands() {
    echo ""
    echo "🔄 MANUAL SYNC COMMANDS"
    echo "======================"
    echo ""
    echo "Sync FROM Google Drive TO Nextcloud:"
    echo "rsync -av /mnt/gdrive/data/ /var/lib/docker/volumes/nextcloud-server_nextcloud_html/_data/data/"
    echo ""
    echo "Sync FROM Nextcloud TO Google Drive:"
    echo "rsync -av /var/lib/docker/volumes/nextcloud-server_nextcloud_html/_data/data/ /mnt/gdrive/data/"
    echo ""
    echo "Setup automatic sync (crontab):"
    echo "*/5 * * * * rsync -av /var/lib/docker/volumes/nextcloud-server_nextcloud_html/_data/data/ /mnt/gdrive/data/"
}

# Main menu
main_menu() {
    echo ""
    echo "🎯 PILIHAN RECONNECT GOOGLE DRIVE:"
    echo "=================================="
    echo ""
    echo "1. Direct Mount (Ganti data ke Google Drive)"
    echo "2. External Storage (Via Nextcloud Apps)"
    echo "3. Manual Sync Commands"
    echo "4. Check Current Setup"
    echo ""
    read -p "Pilih opsi (1-4): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            create_direct_mount
            ;;
        2)
            setup_gdrive_external
            setup_external_storage
            ;;
        3)
            show_sync_commands
            ;;
        4)
            check_current_setup
            ;;
        *)
            echo "❌ Invalid option"
            ;;
    esac
}

# Main execution
echo "Starting Google Drive reconnection process..."
echo ""

check_current_setup
main_menu

echo ""
echo "🎉 Google Drive reconnection process completed!"
echo ""
echo "💡 Recommendation: Gunakan Direct Mount (Option 1) untuk"
echo "   mendapatkan sync otomatis seperti sebelumnya."

