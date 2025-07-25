#!/bin/bash

echo "🔍 FINAL DEBUG & FIX"
echo "==================="
echo ""

# Function to check current state
debug_current_state() {
    echo "📊 Current State Analysis:"
    echo "========================="
    
    # Check containers
    echo "Containers:"
    docker ps | grep nextcloud
    
    # Check Google Drive mount
    echo ""
    echo "Google Drive mount:"
    mountpoint /mnt/gdrive && echo "✅ Mounted" || echo "❌ Not mounted"
    
    # Check data in Google Drive
    echo ""
    echo "Google Drive data contents:"
    ls -la /mnt/gdrive/data/ 2>/dev/null | head -5
    
    # Check container logs
    echo ""
    echo "Container logs (last 10 lines):"
    CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    if [ -n "$CONTAINER" ]; then
        docker logs "$CONTAINER" --tail 10
    fi
    
    # Check config volume
    echo ""
    echo "Config volume contents:"
    docker volume inspect nextcloud-server_nextcloud_config
}

# Function to completely reset config
reset_config_completely() {
    echo ""
    echo "🔄 COMPLETE CONFIG RESET"
    echo "======================="
    
    # Stop containers
    echo "🛑 Stopping containers..."
    docker compose down
    
    # Remove config volume completely
    echo "🗑️ Removing config volume..."
    docker volume rm nextcloud-server_nextcloud_config 2>/dev/null || true
    
    # Clear any existing config in Google Drive
    echo "🧹 Cleaning Google Drive config..."
    sudo rm -rf /mnt/gdrive/config/* 2>/dev/null || true
    
    # Create fresh docker-compose with ONLY Google Drive data (no config volume)
    echo "📝 Creating fresh docker-compose..."
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

networks:
  default:
    name: nextcloud-server_nextcloud
DOCKER_EOF

    echo "✅ Fresh docker-compose created (config in container, data in Google Drive)"
}

# Function to prepare fresh setup
prepare_fresh_setup() {
    echo ""
    echo "🆕 PREPARING FRESH SETUP"
    echo "======================="
    
    # Ensure Google Drive data directory exists and is empty for fresh start
    echo "📁 Preparing Google Drive data directory..."
    sudo mkdir -p /mnt/gdrive/data
    
    # Ask if user wants to keep existing data or start fresh
    read -p "🤔 Keep existing data in /mnt/gdrive/data? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "🧹 Clearing Google Drive data for fresh start..."
        sudo rm -rf /mnt/gdrive/data/*
    fi
    
    # Fix permissions
    sudo chown -R 33:33 /mnt/gdrive/data
    sudo chmod -R 0770 /mnt/gdrive/data
    
    echo "✅ Google Drive data directory prepared"
}

# Function to start and verify
start_and_verify() {
    echo ""
    echo "🚀 STARTING FRESH SETUP"
    echo "======================"
    
    # Start containers
    docker compose up -d
    
    echo "⏳ Waiting 30 seconds for complete startup..."
    sleep 30
    
    # Check status
    echo "📊 Container status:"
    docker compose ps
    
    # Check logs
    echo ""
    echo "📋 Recent logs:"
    CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    if [ -n "$CONTAINER" ]; then
        docker logs "$CONTAINER" --tail 15
    fi
    
    # Test web response
    echo ""
    echo "🌐 Testing web response:"
    curl -I http://localhost:8081 2>/dev/null | head -3 || echo "Web not responding yet"
}

# Function to show final instructions
show_final_instructions() {
    echo ""
    echo "🎯 FINAL INSTRUCTIONS"
    echo "==================="
    echo ""
    echo "1. Access Nextcloud: http://184.105.238.243:8081"
    echo ""
    echo "2. If you see the setup wizard, fill in:"
    echo "   Admin User: admin"
    echo "   Admin Password: (choose your password)"
    echo "   Data Folder: /var/www/html/data (default)"
    echo "   Database Type: MySQL/MariaDB"
    echo "   Database Host: db"
    echo "   Database Name: nextcloud"
    echo "   Database User: nextclouduser"
    echo "   Database Password: Nextcloud123!"
    echo ""
    echo "3. If you see existing Nextcloud, login with your existing credentials"
    echo ""
    echo "✅ Data will be stored in Google Drive: /mnt/gdrive/data/"
    echo "✅ Config will be stored in container (stable)"
    echo ""
    echo "🔍 To verify sync:"
    echo "   - Create a file in Nextcloud web interface"
    echo "   - Check if it appears in: ls -la /mnt/gdrive/data/admin/files/"
}

# Main execution
main() {
    echo "Starting final debug and fix process..."
    echo ""
    
    debug_current_state
    
    echo ""
    read -p "🤔 Proceed with complete reset? This will fix the config issue (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reset_config_completely
        prepare_fresh_setup
        start_and_verify
        show_final_instructions
        
        echo ""
        echo "🎉 SETUP COMPLETED!"
        echo ""
        echo "💡 This setup uses:"
        echo "   - Config: Container storage (stable, no mount issues)"
        echo "   - Data: Google Drive mount (automatic sync)"
        echo "   - Best of both worlds!"
        
    else
        echo "❌ Reset cancelled"
        echo ""
        echo "💡 Alternative: Try accessing http://184.105.238.243:8081"
        echo "   and see current status"
    fi
}

main "$@"
