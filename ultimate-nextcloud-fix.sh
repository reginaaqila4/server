#!/bin/bash

echo "🚨 ULTIMATE NEXTCLOUD FIX"
echo "========================="
echo "IP VPS: 184.105.238.243"
echo ""

# Function to check current state
check_current_state() {
    echo "🔍 Current State Analysis:"
    echo "========================="
    
    # Check containers
    echo "Containers:"
    docker ps | grep nextcloud
    
    # Check volumes
    echo ""
    echo "Volumes:"
    docker volume ls | grep nextcloud
    
    # Check logs
    echo ""
    echo "Recent logs (last 10 lines):"
    CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    if [ -n "$CONTAINER" ]; then
        docker logs "$CONTAINER" --tail 10
    fi
    
    # Check if config exists in volume
    echo ""
    echo "Config volume contents:"
    docker exec "$CONTAINER" ls -la /var/www/html/config/ 2>/dev/null || echo "Cannot access config"
    
    # Check permissions
    echo ""
    echo "Permission check:"
    docker exec "$CONTAINER" id www-data 2>/dev/null || echo "Cannot check www-data"
}

# Function to completely reset and use different approach
complete_reset() {
    echo ""
    echo "🔄 COMPLETE RESET WITH DIFFERENT APPROACH"
    echo "========================================="
    
    # Stop everything
    echo "🛑 Stopping all containers..."
    docker compose down
    
    # Remove ALL nextcloud volumes
    echo "🗑️ Removing all volumes (this will delete existing data)..."
    docker volume rm nextcloud-server_nextcloud_config 2>/dev/null || true
    docker volume rm nextcloud-server_nextcloud_html 2>/dev/null || true
    docker volume rm nextcloud-server_nextcloud_db 2>/dev/null || true
    
    # Create new docker-compose with completely local setup first
    echo "📝 Creating fresh docker-compose.yml..."
    cat > docker-compose.yml << 'DOCKER_EOF'
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

networks:
  default:
    name: nextcloud-server_nextcloud
DOCKER_EOF

    echo "✅ Fresh docker-compose.yml created (completely local setup)"
}

# Function to start and test
start_and_test() {
    echo ""
    echo "🚀 Starting fresh setup..."
    
    # Start containers
    docker compose up -d
    
    echo "⏳ Waiting 30 seconds for complete startup..."
    sleep 30
    
    # Check status
    echo "📊 Container status:"
    docker compose ps
    
    # Check logs
    echo ""
    echo "📋 App container logs:"
    CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    if [ -n "$CONTAINER" ]; then
        docker logs "$CONTAINER" --tail 15
    fi
    
    # Test web response
    echo ""
    echo "🌐 Testing web response:"
    curl -I http://localhost:8081 2>/dev/null | head -3 || echo "Web not responding"
}

# Function to setup data migration later
setup_data_migration() {
    echo ""
    echo "📋 NEXT STEPS FOR DATA MIGRATION:"
    echo "================================="
    echo ""
    echo "1. Akses Nextcloud: http://184.105.238.243:8081"
    echo "2. Lakukan fresh installation dengan data berikut:"
    echo ""
    echo "   📝 Installation Data:"
    echo "   Admin User: admin"
    echo "   Admin Password: (pilih password Anda)"
    echo "   Data Folder: /var/www/html/data (default)"
    echo "   Database Type: MySQL/MariaDB"
    echo "   Database Host: db"
    echo "   Database Name: nextcloud"
    echo "   Database User: nextclouduser"
    echo "   Database Password: Nextcloud123!"
    echo ""
    echo "3. Setelah berhasil install, kita bisa setup external storage"
    echo "   untuk koneksi ke Google Drive melalui External Storage app"
    echo ""
    echo "4. Atau kita bisa migrate data dari /mnt/gdrive/data ke Nextcloud"
    echo ""
    echo "💡 Keuntungan approach ini:"
    echo "   - Nextcloud berjalan stabil dengan local storage"
    echo "   - Bisa sync/backup ke Google Drive via External Storage"
    echo "   - Tidak ada masalah permission atau mount"
}

# Main execution
main() {
    echo "Starting ultimate fix process..."
    echo ""
    
    check_current_state
    
    echo ""
    read -p "🤔 Lakukan complete reset? Ini akan hapus semua data existing (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        complete_reset
        start_and_test
        setup_data_migration
        
        echo ""
        echo "🎉 FRESH SETUP COMPLETED!"
        echo ""
        echo "🔗 URL: http://184.105.238.243:8081"
        echo ""
        echo "⚠️  IMPORTANT: Setup ini menggunakan local storage."
        echo "   Untuk Google Drive integration, gunakan External Storage app"
        echo "   setelah Nextcloud berhasil running."
        
    else
        echo "❌ Reset cancelled"
        echo ""
        echo "💡 Alternative: Coba akses http://184.105.238.243:8081"
        echo "   dan lihat apakah setup wizard muncul"
    fi
}

main "$@"
