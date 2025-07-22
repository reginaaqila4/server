#!/bin/bash

echo "🔧 ALTERNATIVE FIX: Use Local Volume for Config"
echo "=============================================="

echo "Masalah: Google Drive mount mungkin tidak cocok untuk config.php"
echo "Solusi: Gunakan local volume untuk config, Google Drive hanya untuk data"
echo ""

# Function to backup current setup
backup_current() {
    echo "📦 Backing up current docker-compose.yml..."
    cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d_%H%M%S)
    echo "✅ Backup created"
}

# Function to modify docker-compose.yml
modify_compose() {
    echo ""
    echo "📝 Modifying docker-compose.yml to use local volume for config..."
    
    cat > docker-compose-fixed.yml << 'DOCKER_EOF'
version: '3.8'

networks:
  nextcloud:
    driver: bridge

services:
  db:
    image: mysql:8.0.36-debian
    container_name: ${COMPOSE_PROJECT_NAME}-db
    restart: always
    command: --default-authentication-plugin=mysql_native_password --innodb-buffer-pool-size=512M
    networks:
      - nextcloud
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
    networks:
      - nextcloud
    command: redis-server --requirepass ${REDIS_PASSWORD}

  app:
    image: nextcloud:apache
    container_name: ${COMPOSE_PROJECT_NAME}-app
    restart: always
    ports:
      - "8081:80"
    networks:
      - nextcloud
    depends_on:
      - db
    volumes:
      - nextcloud_html:/var/www/html
      - nextcloud_config:/var/www/html/config
      - /mnt/gdrive/data:/var/www/html/data
    environment:
      - MYSQL_HOST=db
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_HOST_PASSWORD=${REDIS_PASSWORD}
      - NEXTCLOUD_TRUSTED_DOMAINS=${TRUSTED_DOMAINS}
      - OVERWRITEPROTOCOL=http
      - OVERWRITECLIURL=http://${DOMAIN}
      - APACHE_DISABLE_REWRITE_IP=1

volumes:
  nextcloud_db:
  nextcloud_html:
  nextcloud_config:
DOCKER_EOF

    echo "✅ New docker-compose.yml created with local config volume"
}

# Function to apply the fix
apply_fix() {
    echo ""
    echo "🚀 Applying the fix..."
    
    # Stop containers
    echo "🛑 Stopping containers..."
    docker compose down
    
    # Remove old volumes (optional)
    read -p "🤔 Remove old volumes? This will delete existing config (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume rm nextcloud-server_nextcloud_config 2>/dev/null || true
        echo "✅ Old config volume removed"
    fi
    
    # Use new compose file
    cp docker-compose-fixed.yml docker-compose.yml
    
    # Start with new configuration
    echo "🚀 Starting with new configuration..."
    docker compose up -d
    
    echo "⏳ Waiting 20 seconds for startup..."
    sleep 20
    
    echo "📊 Container status:"
    docker compose ps
}

# Function to show access info
show_info() {
    echo ""
    echo "🌐 Access Information:"
    echo "====================="
    echo "URL: http://10.64.3.207:8081"
    echo ""
    echo "📝 Installation Data:"
    echo "===================="
    echo "Admin User: admin"
    echo "Admin Password: (choose your password)"
    echo "Data Folder: /var/www/html/data"
    echo "Database Type: MySQL/MariaDB"
    echo "Database Host: db"
    echo "Database Name: nextcloud"
    echo "Database User: nextclouduser"
    echo "Database Password: Nextcloud123!"
    echo ""
    echo "✅ Config akan disimpan di local Docker volume"
    echo "✅ Data akan disimpan di Google Drive (/mnt/gdrive/data)"
}

# Main execution
main() {
    if [ ! -f "docker-compose.yml" ]; then
        echo "❌ docker-compose.yml not found. Please run from nextcloud-server directory"
        exit 1
    fi
    
    backup_current
    modify_compose
    
    read -p "🤔 Apply this fix? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apply_fix
        show_info
        
        echo ""
        echo "🎉 Fix applied! Try accessing Nextcloud now."
        echo ""
        echo "💡 Keuntungan setup ini:"
        echo "   - Config disimpan di local volume (lebih stabil)"
        echo "   - Data tetap di Google Drive (backup otomatis)"
        echo "   - Tidak ada masalah permission dengan config.php"
    else
        echo "❌ Fix cancelled"
        rm docker-compose-fixed.yml
    fi
}

main "$@"
