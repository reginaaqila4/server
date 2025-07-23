#!/bin/bash

echo "🔧 FIX NEXTCLOUD DATA DIRECTORY ERROR"
echo "====================================="
echo ""

# Function to diagnose current state
diagnose_current_state() {
    echo "🔍 Diagnosing current state..."
    echo "=========================="
    
    # Check Google Drive mount
    echo "1. Google Drive mount status:"
    if mountpoint -q /mnt/gdrive; then
        echo "   ✅ /mnt/gdrive is mounted"
        echo "   📁 Contents:"
        ls -la /mnt/gdrive/ | head -5
    else
        echo "   ❌ /mnt/gdrive is NOT mounted"
    fi
    
    # Check data directory
    echo ""
    echo "2. Data directory status:"
    if [ -d "/mnt/gdrive/nextcloud-data" ]; then
        echo "   ✅ /mnt/gdrive/nextcloud-data exists"
        echo "   🔒 Permissions:"
        ls -la /mnt/gdrive/ | grep nextcloud-data
        echo "   📂 Contents:"
        ls -la /mnt/gdrive/nextcloud-data/ 2>/dev/null | head -5
    else
        echo "   ❌ /mnt/gdrive/nextcloud-data does NOT exist"
    fi
    
    # Check containers
    echo ""
    echo "3. Container status:"
    docker ps | grep nextcloud || echo "   ❌ No nextcloud containers running"
    
    # Check .ncdata file
    echo ""
    echo "4. .ncdata file check:"
    if [ -f "/mnt/gdrive/nextcloud-data/.ncdata" ]; then
        echo "   ✅ .ncdata exists"
        echo "   Content: $(cat /mnt/gdrive/nextcloud-data/.ncdata)"
    else
        echo "   ❌ .ncdata file missing"
    fi
}

# Function to fix the issues
fix_data_directory() {
    echo ""
    echo "🛠️ Fixing data directory issues..."
    echo "================================"
    
    # Stop containers first
    echo "1. Stopping containers..."
    cd ~/nextcloud-auto-gdrive 2>/dev/null || cd ~
    docker compose down 2>/dev/null || true
    
    # Ensure Google Drive is mounted
    echo ""
    echo "2. Ensuring Google Drive mount..."
    if ! mountpoint -q /mnt/gdrive; then
        echo "   Mounting Google Drive..."
        sudo rclone mount alldrive: /mnt/gdrive \
          --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \
          --allow-other --allow-non-empty \
          --uid=33 --gid=33 --umask=007 \
          --vfs-cache-mode=full --vfs-cache-max-size=5G \
          --daemon
        
        sleep 10
        
        if mountpoint -q /mnt/gdrive; then
            echo "   ✅ Google Drive mounted successfully"
        else
            echo "   ❌ Failed to mount Google Drive"
            return 1
        fi
    else
        echo "   ✅ Google Drive already mounted"
    fi
    
    # Clean and recreate data directory
    echo ""
    echo "3. Recreating data directory..."
    sudo rm -rf /mnt/gdrive/nextcloud-data
    sudo mkdir -p /mnt/gdrive/nextcloud-data
    
    # Set correct permissions
    echo ""
    echo "4. Setting correct permissions..."
    sudo chown -R 33:33 /mnt/gdrive/nextcloud-data
    sudo chmod -R 0770 /mnt/gdrive/nextcloud-data
    
    # Create .ncdata file
    echo ""
    echo "5. Creating .ncdata file..."
    echo "# Nextcloud data directory" | sudo tee /mnt/gdrive/nextcloud-data/.ncdata > /dev/null
    sudo chown 33:33 /mnt/gdrive/nextcloud-data/.ncdata
    sudo chmod 660 /mnt/gdrive/nextcloud-data/.ncdata
    
    echo "   ✅ .ncdata file created"
    
    # Verify permissions
    echo ""
    echo "6. Verifying setup..."
    ls -la /mnt/gdrive/ | grep nextcloud-data
    ls -la /mnt/gdrive/nextcloud-data/
    
    echo "   ✅ Data directory setup completed"
}

# Function to fix docker-compose configuration
fix_docker_compose() {
    echo ""
    echo "📝 Fixing docker-compose configuration..."
    echo "======================================="
    
    cd ~/nextcloud-auto-gdrive
    
    # Create corrected .env file
    echo "Creating corrected .env file..."
    cat > .env << 'ENV_EOF'
# ===== PROJECT CONFIG =====
COMPOSE_PROJECT_NAME=nextcloud-server

# ===== DATABASE CONFIG =====
MYSQL_ROOT_PASSWORD=Nextcloud123!
MYSQL_PASSWORD=Nextcloud123!
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextclouduser

# ===== REDIS CONFIG =====
REDIS_PASSWORD=Nextcloud123!

# ===== NEXTCLOUD CONFIG =====
TRUSTED_DOMAINS=localhost,127.0.0.1:8081,47.236.62.121,47.236.62.121:8081
DOMAIN=47.236.62.121

# ===== ADMIN USER (First install)
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=Dimas112233!
ENV_EOF

    # Create corrected docker-compose.yml
    echo "Creating corrected docker-compose.yml..."
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
      - nextcloud_config:/var/www/html/config
      - /mnt/gdrive/nextcloud-data:/var/www/html/data
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
  nextcloud_config:

networks:
  default:
    name: ${COMPOSE_PROJECT_NAME}_network
COMPOSE_EOF

    echo "✅ Docker configuration files updated"
}

# Function to start fresh deployment
start_fresh_deployment() {
    echo ""
    echo "🚀 Starting fresh deployment..."
    echo "============================="
    
    cd ~/nextcloud-auto-gdrive
    
    # Remove old volumes
    echo "1. Cleaning old volumes..."
    docker volume rm nextcloud-server_nextcloud_config 2>/dev/null || true
    docker volume rm nextcloud-server_nextcloud_html 2>/dev/null || true
    docker volume rm nextcloud-server_nextcloud_db 2>/dev/null || true
    
    # Start containers
    echo ""
    echo "2. Starting containers..."
    docker compose --env-file .env up -d
    
    echo ""
    echo "3. Waiting for startup (60 seconds)..."
    sleep 60
    
    # Check status
    echo ""
    echo "4. Checking container status..."
    docker compose ps
    
    # Check logs
    echo ""
    echo "5. Checking logs..."
    docker compose logs app | tail -10
    
    echo ""
    echo "✅ Fresh deployment completed"
}

# Function to show access instructions
show_access_instructions() {
    echo ""
    echo "🌐 ACCESS INSTRUCTIONS"
    echo "====================="
    echo ""
    echo "1. Access URL: http://47.236.62.121:8081"
    echo ""
    echo "2. Setup form:"
    echo "   Admin Username: admin"
    echo "   Admin Password: Dimas112233!"
    echo "   Data Folder: /var/www/html/data (KEEP DEFAULT)"
    echo "   Database Type: MySQL/MariaDB"
    echo "   Database Host: db"
    echo "   Database Name: nextcloud"
    echo "   Database User: nextclouduser"
    echo "   Database Password: Nextcloud123!"
    echo ""
    echo "3. Click 'Finish Setup'"
    echo ""
    echo "✅ After setup, all uploads will go to Google Drive automatically!"
}

# Main execution
main() {
    echo "Starting Nextcloud data directory fix..."
    echo ""
    
    diagnose_current_state
    
    echo ""
    read -p "🤔 Proceed with fixing the data directory issues? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        fix_data_directory
        
        if [ $? -eq 0 ]; then
            fix_docker_compose
            start_fresh_deployment
            show_access_instructions
            
            echo ""
            echo "🎉 FIX COMPLETED!"
            echo ""
            echo "💡 Key fixes applied:"
            echo "   - Recreated data directory with correct permissions"
            echo "   - Created .ncdata file"
            echo "   - Fixed docker-compose configuration"
            echo "   - Added Redis for better performance"
            echo "   - Fresh container deployment"
            
        else
            echo "❌ Failed to fix data directory. Check Google Drive mount."
        fi
        
    else
        echo "❌ Fix cancelled"
    fi
}

main "$@"
