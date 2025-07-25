#!/bin/bash

echo "🔄 FORCE RESET - Complete Nextcloud Reset"
echo "========================================"
echo ""

# Function to backup important data
backup_data() {
    echo "📦 Backing up important data..."
    
    # Create backup directory
    mkdir -p ~/nextcloud-backup-$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR=~/nextcloud-backup-$(date +%Y%m%d_%H%M%S)
    
    # Backup docker-compose files
    cp ~/nextcloud-server/docker-compose.yml* "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup .env file
    cp ~/nextcloud-server/.env "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup Google Drive data if accessible
    if [ -d "/mnt/gdrive/data" ]; then
        echo "Google Drive data found - noting location"
        echo "/mnt/gdrive/data/" > "$BACKUP_DIR/gdrive_data_location.txt"
    fi
    
    echo "✅ Backup created in: $BACKUP_DIR"
}

# Function to complete cleanup
complete_cleanup() {
    echo ""
    echo "🧹 Complete Cleanup..."
    echo "===================="
    
    # Stop all containers
    echo "🛑 Stopping all containers..."
    cd ~/nextcloud-server
    docker compose down 2>/dev/null || true
    
    # Remove all nextcloud containers
    echo "🗑️ Removing containers..."
    docker rm -f $(docker ps -a | grep nextcloud | awk '{print $1}') 2>/dev/null || true
    
    # Remove all nextcloud volumes
    echo "🗑️ Removing volumes..."
    docker volume rm $(docker volume ls | grep nextcloud | awk '{print $2}') 2>/dev/null || true
    
    # Remove nextcloud images (optional)
    read -p "🤔 Remove Nextcloud images to force fresh download? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker rmi nextcloud:apache 2>/dev/null || true
        docker rmi mysql:8.0.36-debian 2>/dev/null || true
        docker rmi redis:alpine 2>/dev/null || true
    fi
    
    # Clean docker system
    echo "🧹 Cleaning Docker system..."
    docker system prune -f
    
    echo "✅ Complete cleanup done"
}

# Function to create fresh setup
create_fresh_setup() {
    echo ""
    echo "🆕 Creating Fresh Setup..."
    echo "========================="
    
    # Create fresh directory
    cd ~
    rm -rf ~/nextcloud-server-fresh
    mkdir -p ~/nextcloud-server-fresh
    cd ~/nextcloud-server-fresh
    
    # Create fresh .env file
    cat > .env << 'ENV_EOF'
# ===== PROJECT CONFIG =====
COMPOSE_PROJECT_NAME=nextcloud-fresh

# ===== DATABASE CONFIG =====
MYSQL_ROOT_PASSWORD=Nextcloud123!
MYSQL_PASSWORD=Nextcloud123!
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextclouduser

# ===== REDIS CONFIG =====
REDIS_PASSWORD=Nextcloud123!

# ===== NEXTCLOUD CONFIG =====
TRUSTED_DOMAINS=localhost,127.0.0.1:8081,184.105.238.243,184.105.238.243:8081
DOMAIN=184.105.238.243

# ===== ADMIN USER =====
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=AdminPass123!
ENV_EOF

    # Create fresh docker-compose (local storage only)
    cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  db:
    image: mysql:8.0.36-debian
    container_name: ${COMPOSE_PROJECT_NAME}-db
    restart: always
    command: --default-authentication-plugin=mysql_native_password --innodb-buffer-pool-size=512M
    volumes:
      - nextcloud_db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}

  redis:
    image: redis:alpine
    container_name: ${COMPOSE_PROJECT_NAME}-redis
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD}

  app:
    image: nextcloud:apache
    container_name: ${COMPOSE_PROJECT_NAME}-app
    restart: always
    ports:
      - "8081:80"
    depends_on:
      - db
      - redis
    volumes:
      - nextcloud_html:/var/www/html
    environment:
      - MYSQL_HOST=db
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_HOST_PASSWORD=${REDIS_PASSWORD}
      - NEXTCLOUD_TRUSTED_DOMAINS=${TRUSTED_DOMAINS}
      - OVERWRITEPROTOCOL=http
      - OVERWRITECLIURL=http://${DOMAIN}:8081
      - APACHE_DISABLE_REWRITE_IP=1

volumes:
  nextcloud_db:
  nextcloud_html:

networks:
  default:
    name: nextcloud-fresh_default
COMPOSE_EOF

    echo "✅ Fresh setup created"
}

# Function to start fresh installation
start_fresh() {
    echo ""
    echo "🚀 Starting Fresh Installation..."
    echo "==============================="
    
    # Start containers
    docker compose up -d
    
    echo "⏳ Waiting 45 seconds for complete startup..."
    sleep 45
    
    # Check status
    echo "📊 Container status:"
    docker compose ps
    
    # Test web response
    echo ""
    echo "🌐 Testing web response:"
    curl -I http://localhost:8081 2>/dev/null | head -3 || echo "Still starting up..."
    
    echo ""
    echo "🎉 Fresh installation started!"
    echo ""
    echo "🔗 Access URL: http://184.105.238.243:8081"
    echo ""
    echo "📝 Setup Information:"
    echo "===================="
    echo "Admin User: admin"
    echo "Admin Password: AdminPass123!"
    echo "Data Folder: /var/www/html/data (default)"
    echo "Database Type: MySQL/MariaDB"
    echo "Database Host: db"
    echo "Database Name: nextcloud"
    echo "Database User: nextclouduser"
    echo "Database Password: Nextcloud123!"
}

# Main execution
main() {
    echo "⚠️  WARNING: This will completely reset Nextcloud!"
    echo "All existing configuration will be lost."
    echo ""
    
    read -p "🤔 Continue with force reset? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        backup_data
        complete_cleanup
        create_fresh_setup
        start_fresh
        
        echo ""
        echo "🎉 FORCE RESET COMPLETED!"
        echo ""
        echo "💡 Next steps:"
        echo "1. Access http://184.105.238.243:8081"
        echo "2. Complete setup wizard"
        echo "3. After stable, add Google Drive integration"
        echo ""
        echo "📁 Project location: ~/nextcloud-server-fresh"
        
    else
        echo "❌ Force reset cancelled"
    fi
}

main "$@"
