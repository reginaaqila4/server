#!/bin/bash

echo "📁 SETUP EXTERNAL STORAGE - Google Drive Only for Upload"
echo "======================================================="
echo ""
echo "Konsep: Nextcloud normal di VPS + External Storage ke Google Drive"
echo ""

# Function to setup stable Nextcloud
setup_stable_nextcloud() {
    echo "🏗️  Setting up stable Nextcloud (local storage)..."
    echo "==============================================="
    
    # Create fresh directory
    cd ~
    mkdir -p ~/nextcloud-stable
    cd ~/nextcloud-stable
    
    # Create simple docker-compose for stable setup
    cat > docker-compose.yml << 'COMPOSE_EOF'
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
COMPOSE_EOF

    echo "✅ Stable docker-compose.yml created"
}

# Function to start Nextcloud
start_nextcloud() {
    echo ""
    echo "🚀 Starting stable Nextcloud..."
    echo "============================="
    
    docker compose up -d
    
    echo "⏳ Waiting 30 seconds for startup..."
    sleep 30
    
    echo "📊 Container status:"
    docker compose ps
    
    echo ""
    echo "🌐 Testing web access:"
    curl -I http://localhost:8081 2>/dev/null | head -3 || echo "Still starting..."
}

# Function to install External Storage app
install_external_storage() {
    echo ""
    echo "📦 Installing External Storage App..."
    echo "===================================="
    
    CONTAINER=$(docker ps | grep nextcloud-stable-app | awk '{print $1}')
    
    if [ -n "$CONTAINER" ]; then
        echo "Installing and enabling External Storage support..."
        
        # Wait for Nextcloud to be fully ready
        echo "⏳ Waiting for Nextcloud to be ready..."
        sleep 10
        
        # Install External Storage app
        docker exec -u www-data "$CONTAINER" php occ app:install files_external
        docker exec -u www-data "$CONTAINER" php occ app:enable files_external
        
        echo "✅ External Storage app installed"
        
        # Check if app is enabled
        docker exec -u www-data "$CONTAINER" php occ app:list | grep files_external
        
    else
        echo "❌ Container not found or not running"
        return 1
    fi
}

# Function to setup Google Drive credentials
setup_gdrive_credentials() {
    echo ""
    echo "🔑 Google Drive Integration Setup"
    echo "==============================="
    echo ""
    echo "Untuk menghubungkan ke Google Drive, Anda perlu:"
    echo ""
    echo "1️⃣ Google Cloud Console Setup:"
    echo "   - Buka: https://console.cloud.google.com/"
    echo "   - Buat project baru atau pilih existing"
    echo "   - Enable Google Drive API"
    echo "   - Buat OAuth 2.0 credentials"
    echo "   - Download client_secret.json"
    echo ""
    echo "2️⃣ Setup di Nextcloud Web Interface:"
    echo "   - Login ke: http://184.105.238.243:8081"
    echo "   - Pergi ke: Settings → Administration → External storages"
    echo "   - Add storage → Google Drive"
    echo "   - Masukkan Client ID dan Client Secret"
    echo "   - Folder name: 'GoogleDrive' (atau nama yang Anda suka)"
    echo "   - Klik Save"
    echo ""
    echo "3️⃣ Authorize Access:"
    echo "   - Klik tombol authorize"
    echo "   - Login dengan Google account"
    echo "   - Grant permissions"
    echo ""
    echo "✅ Setelah setup, Anda akan punya:"
    echo "   - /Local/ → Storage VPS normal"
    echo "   - /GoogleDrive/ → Langsung ke Google Drive"
}

# Function to setup rclone integration (alternative)
setup_rclone_integration() {
    echo ""
    echo "🔄 Alternative: Rclone Integration"
    echo "================================="
    echo ""
    echo "Jika ingin pakai rclone existing:"
    echo ""
    echo "1. Mount Google Drive di VPS:"
    echo "   sudo mkdir -p /mnt/nextcloud-gdrive"
    echo "   sudo rclone mount alldrive: /mnt/nextcloud-gdrive \\"
    echo "     --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \\"
    echo "     --allow-other --daemon"
    echo ""
    echo "2. Setup External Storage di Nextcloud:"
    echo "   - Type: Local"
    echo "   - Folder: /mnt/nextcloud-gdrive"
    echo "   - Mount point: /GoogleDrive"
    echo ""
    echo "3. Update docker-compose.yml add volume:"
    echo "   volumes:"
    echo "     - /mnt/nextcloud-gdrive:/mnt/nextcloud-gdrive"
}

# Function to show final instructions
show_final_instructions() {
    echo ""
    echo "🎯 FINAL SETUP INSTRUCTIONS"
    echo "=========================="
    echo ""
    echo "1. Access Nextcloud: http://184.105.238.243:8081"
    echo ""
    echo "2. Complete initial setup:"
    echo "   Admin User: admin"
    echo "   Admin Password: (pilih password)"
    echo "   Database Host: db"
    echo "   Database Name: nextcloud"
    echo "   Database User: nextclouduser"
    echo "   Database Password: Nextcloud123!"
    echo ""
    echo "3. After login, go to:"
    echo "   Settings → Administration → External storages"
    echo ""
    echo "4. Setup Google Drive external storage"
    echo ""
    echo "✅ HASIL:"
    echo "   - Nextcloud stabil di VPS"
    echo "   - Config & database di VPS"
    echo "   - Upload bisa ke local VPS atau Google Drive"
    echo "   - Tidak ada masalah mount atau config"
    echo ""
    echo "📁 File Structure:"
    echo "   /admin/files/ → Local VPS storage"
    echo "   /admin/files/GoogleDrive/ → Direct ke Google Drive"
}

# Main execution
main() {
    echo "Setting up Nextcloud with External Storage for Google Drive..."
    echo ""
    
    # Stop any existing problematic setup
    cd ~/nextcloud-server 2>/dev/null && docker compose down 2>/dev/null || true
    
    setup_stable_nextcloud
    start_nextcloud
    
    # Wait for proper startup
    echo ""
    read -p "🤔 Nextcloud started. Continue with External Storage setup? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_external_storage
        setup_gdrive_credentials
        setup_rclone_integration
        show_final_instructions
        
        echo ""
        echo "🎉 SETUP COMPLETED!"
        echo ""
        echo "💡 This approach gives you:"
        echo "   - Stable Nextcloud (no mount issues)"
        echo "   - Choice: upload to VPS or Google Drive"
        echo "   - Easy to manage and backup"
        echo "   - No config conflicts"
        
    else
        show_final_instructions
    fi
}

main "$@"
