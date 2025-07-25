#!/bin/bash

echo "🚨 EMERGENCY FIX - Internal Server Error"
echo "========================================"
echo ""

# Function to check container status
check_containers() {
    echo "📊 Container Status:"
    echo "==================="
    docker ps -a | grep nextcloud
    echo ""
    
    echo "📋 Container Logs:"
    echo "=================="
    CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    if [ -n "$CONTAINER" ]; then
        echo "App container logs (last 20 lines):"
        docker logs "$CONTAINER" --tail 20
    else
        echo "❌ No app container running"
        # Check stopped containers
        STOPPED_CONTAINER=$(docker ps -a | grep nextcloud-.*-app | awk '{print $1}')
        if [ -n "$STOPPED_CONTAINER" ]; then
            echo "Stopped container logs:"
            docker logs "$STOPPED_CONTAINER" --tail 20
        fi
    fi
}

# Function to check mounts and permissions
check_mounts() {
    echo ""
    echo "📁 Mount and Permission Check:"
    echo "============================="
    
    # Check Google Drive mount
    if mountpoint -q /mnt/gdrive; then
        echo "✅ Google Drive mounted"
        echo "Data directory:"
        ls -la /mnt/gdrive/data/ 2>/dev/null | head -5
        
        # Check permissions
        echo ""
        echo "Permission check:"
        stat /mnt/gdrive/data/ 2>/dev/null || echo "Cannot stat data directory"
    else
        echo "❌ Google Drive NOT mounted"
    fi
    
    # Check if container can access mount
    CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    if [ -n "$CONTAINER" ]; then
        echo ""
        echo "Container mount check:"
        docker exec "$CONTAINER" ls -la /var/www/html/data/ 2>/dev/null || echo "Container cannot access data"
    fi
}

# Function to fix common issues
fix_common_issues() {
    echo ""
    echo "�� Fixing Common Issues:"
    echo "======================="
    
    # Stop containers
    echo "🛑 Stopping containers..."
    docker compose down
    
    # Check and fix Google Drive mount
    if ! mountpoint -q /mnt/gdrive; then
        echo "🔄 Remounting Google Drive..."
        sudo rclone mount alldrive: /mnt/gdrive \
          --config=/home/paperspace/nextcloud-server/rclone/rclone.conf \
          --allow-other --allow-non-empty \
          --uid=33 --gid=33 --umask=007 \
          --vfs-cache-mode=full --daemon
        
        sleep 10
    fi
    
    # Recreate data directory with proper permissions
    echo "📁 Fixing data directory..."
    sudo mkdir -p /mnt/gdrive/data
    sudo chown -R 33:33 /mnt/gdrive/data
    sudo chmod -R 0770 /mnt/gdrive/data
    
    # Create minimal docker-compose for debugging
    echo "📝 Creating minimal docker-compose..."
    cat > docker-compose-minimal.yml << 'DOCKER_EOF'
services:
  db:
    image: mysql:8.0.36-debian
    container_name: nextcloud-server-db
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
      - NEXTCLOUD_TRUSTED_DOMAINS=localhost,127.0.0.1:8081,184.105.238.243,184.105.238.243:8081

volumes:
  nextcloud_db:
  nextcloud_html:
DOCKER_EOF

    echo "✅ Minimal compose created (local storage only)"
}

# Function to test basic functionality
test_basic() {
    echo ""
    echo "🧪 Testing Basic Functionality:"
    echo "=============================="
    
    # Start with minimal setup
    echo "🚀 Starting minimal setup..."
    docker compose -f docker-compose-minimal.yml up -d
    
    echo "⏳ Waiting 30 seconds..."
    sleep 30
    
    # Check status
    echo "📊 Status:"
    docker compose -f docker-compose-minimal.yml ps
    
    # Check logs
    echo ""
    echo "📋 Logs:"
    CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    if [ -n "$CONTAINER" ]; then
        docker logs "$CONTAINER" --tail 10
    fi
    
    # Test web response
    echo ""
    echo "🌐 Testing web response:"
    curl -I http://localhost:8081 2>/dev/null | head -3 || echo "Web not responding"
}

# Function to restore with Google Drive
restore_gdrive() {
    echo ""
    echo "🔄 Restoring Google Drive Integration:"
    echo "====================================="
    
    read -p "🤔 Basic test successful? Restore Google Drive integration? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Stop minimal setup
        docker compose -f docker-compose-minimal.yml down
        
        # Update to include Google Drive
        cat > docker-compose.yml << 'DOCKER_EOF'
services:
  db:
    image: mysql:8.0.36-debian
    container_name: nextcloud-server-db
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
      - NEXTCLOUD_TRUSTED_DOMAINS=localhost,127.0.0.1:8081,184.105.238.243,184.105.238.243:8081

volumes:
  nextcloud_db:
  nextcloud_html:
DOCKER_EOF

        # Start with Google Drive
        docker compose up -d
        
        echo "✅ Google Drive integration restored"
        echo "🔗 Access: http://184.105.238.243:8081"
        
    else
        echo "ℹ️  Keep minimal setup for now"
        echo "🔗 Access: http://184.105.238.243:8081"
    fi
}

# Main execution
main() {
    echo "Starting emergency fix..."
    echo ""
    
    check_containers
    check_mounts
    
    echo ""
    read -p "🤔 Proceed with emergency fix? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        fix_common_issues
        test_basic
        restore_gdrive
        
        echo ""
        echo "🎉 Emergency fix completed!"
        echo ""
        echo "💡 If still having issues:"
        echo "   - Check logs: docker logs CONTAINER_ID"
        echo "   - Try: docker compose restart"
        echo "   - Check disk space: df -h"
        
    else
        echo "❌ Emergency fix cancelled"
    fi
}

main "$@"
