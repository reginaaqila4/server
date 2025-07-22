#!/bin/bash

echo "🔍 DETAILED NEXTCLOUD DEBUG"
echo "==========================="

# Function to check container logs
check_logs() {
    echo ""
    echo "📋 Container Logs (last 20 lines):"
    echo "=================================="
    
    CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    if [ -n "$CONTAINER" ]; then
        echo "🐳 Nextcloud App Container Logs:"
        docker logs "$CONTAINER" --tail 20
    else
        echo "❌ No Nextcloud container found"
    fi
}

# Function to check mount and permissions in detail
check_mount_detailed() {
    echo ""
    echo "📁 Mount and Permission Details:"
    echo "==============================="
    
    echo "Mount info:"
    mount | grep gdrive
    
    echo ""
    echo "Config directory details:"
    ls -la /mnt/gdrive/config/ 2>/dev/null || echo "Config directory not accessible"
    
    echo ""
    echo "Data directory details:"
    ls -la /mnt/gdrive/data/ 2>/dev/null || echo "Data directory not accessible"
    
    echo ""
    echo "Check if www-data can write to config:"
    sudo -u www-data touch /mnt/gdrive/config/test-write 2>/dev/null && echo "✅ www-data can write" || echo "❌ www-data cannot write"
    sudo rm /mnt/gdrive/config/test-write 2>/dev/null || true
}

# Function to check inside container
check_inside_container() {
    echo ""
    echo "🐳 Inside Container Check:"
    echo "========================="
    
    CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    if [ -n "$CONTAINER" ]; then
        echo "Checking paths inside container:"
        docker exec "$CONTAINER" ls -la /var/www/html/config/ 2>/dev/null || echo "Config path not accessible in container"
        docker exec "$CONTAINER" ls -la /var/www/html/data/ 2>/dev/null || echo "Data path not accessible in container"
        
        echo ""
        echo "Checking if www-data can write inside container:"
        docker exec -u www-data "$CONTAINER" touch /var/www/html/config/test-container 2>/dev/null && echo "✅ www-data can write in container" || echo "❌ www-data cannot write in container"
        docker exec "$CONTAINER" rm /var/www/html/config/test-container 2>/dev/null || true
        
        echo ""
        echo "Check PHP errors:"
        docker exec "$CONTAINER" php -r "echo 'PHP is working\n';" 2>/dev/null || echo "❌ PHP error"
        
    else
        echo "❌ No container found"
    fi
}

# Function to test database connection
test_database() {
    echo ""
    echo "🗄️ Database Connection Test:"
    echo "==========================="
    
    APP_CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    DB_CONTAINER=$(docker ps | grep nextcloud-.*-db | awk '{print $1}')
    
    if [ -n "$DB_CONTAINER" ]; then
        echo "Testing DB connection from app container:"
        if [ -n "$APP_CONTAINER" ]; then
            docker exec "$APP_CONTAINER" nc -z db 3306 && echo "✅ DB connection OK" || echo "❌ DB connection failed"
        fi
        
        echo ""
        echo "Testing DB login:"
        docker exec "$DB_CONTAINER" mysql -u nextclouduser -pNextcloud123! -e "SELECT 1;" 2>/dev/null && echo "✅ DB login OK" || echo "❌ DB login failed"
    else
        echo "❌ No DB container found"
    fi
}

# Main execution
echo "Running detailed debug..."
check_logs
check_mount_detailed
check_inside_container
test_database

echo ""
echo "🛠️ SUGGESTED FIXES:"
echo "=================="
echo "1. Try recreating containers with fresh volumes"
echo "2. Use local volume instead of Google Drive mount for config"
echo "3. Check if SELinux/AppArmor is blocking access"
echo "4. Try different mount options"

