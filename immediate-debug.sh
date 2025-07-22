#!/bin/bash

echo "🔍 IMMEDIATE DEBUG - Internal Server Error"
echo "========================================="
echo ""

# Function to check container status
check_containers() {
    echo "📊 Container Status Check:"
    echo "========================="
    
    echo "All Nextcloud containers:"
    docker ps -a | grep nextcloud
    
    echo ""
    echo "Container details:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep nextcloud
}

# Function to check logs
check_logs() {
    echo ""
    echo "📋 Container Logs Analysis:"
    echo "=========================="
    
    # App container logs
    APP_CONTAINER=$(docker ps -a | grep nextcloud-.*-app | awk '{print $1}')
    if [ -n "$APP_CONTAINER" ]; then
        echo "App container logs (last 30 lines):"
        echo "-----------------------------------"
        docker logs "$APP_CONTAINER" --tail 30
    else
        echo "❌ No app container found"
    fi
    
    echo ""
    
    # DB container logs
    DB_CONTAINER=$(docker ps -a | grep nextcloud-.*-db | awk '{print $1}')
    if [ -n "$DB_CONTAINER" ]; then
        echo "Database container logs (last 15 lines):"
        echo "---------------------------------------"
        docker logs "$DB_CONTAINER" --tail 15
    else
        echo "❌ No database container found"
    fi
}

# Function to check system resources
check_resources() {
    echo ""
    echo "💾 System Resources:"
    echo "==================="
    
    echo "Disk space:"
    df -h | grep -E "(Filesystem|/dev/|tmpfs)" | head -5
    
    echo ""
    echo "Memory usage:"
    free -h
    
    echo ""
    echo "Docker system info:"
    docker system df
}

# Function to check mounts
check_mounts() {
    echo ""
    echo "📁 Mount Status:"
    echo "==============="
    
    echo "Google Drive mount:"
    if mountpoint -q /mnt/gdrive; then
        echo "✅ /mnt/gdrive is mounted"
        echo "Mount details:"
        mount | grep gdrive
        
        echo ""
        echo "Data directory access:"
        ls -la /mnt/gdrive/data/ 2>/dev/null | head -5 || echo "Cannot access data directory"
    else
        echo "❌ /mnt/gdrive is NOT mounted"
    fi
    
    echo ""
    echo "Docker volumes:"
    docker volume ls | grep nextcloud
}

# Function to test container access
test_container_access() {
    echo ""
    echo "🧪 Container Access Test:"
    echo "========================"
    
    APP_CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    if [ -n "$APP_CONTAINER" ]; then
        echo "Testing container shell access:"
        docker exec "$APP_CONTAINER" echo "Container accessible" 2>/dev/null || echo "❌ Cannot access container"
        
        echo ""
        echo "Testing file system access:"
        docker exec "$APP_CONTAINER" ls -la /var/www/html/ 2>/dev/null | head -5 || echo "❌ Cannot access HTML directory"
        
        echo ""
        echo "Testing data directory:"
        docker exec "$APP_CONTAINER" ls -la /var/www/html/data/ 2>/dev/null | head -3 || echo "❌ Cannot access data directory"
        
        echo ""
        echo "Testing PHP:"
        docker exec "$APP_CONTAINER" php -v 2>/dev/null | head -1 || echo "❌ PHP not working"
        
    else
        echo "❌ No running app container to test"
    fi
}

# Function to check web response
test_web_response() {
    echo ""
    echo "🌐 Web Response Test:"
    echo "===================="
    
    echo "Testing local connection:"
    curl -I http://localhost:8081 2>/dev/null | head -5 || echo "❌ No response from localhost:8081"
    
    echo ""
    echo "Testing external IP:"
    curl -I http://184.105.238.243:8081 2>/dev/null | head -5 || echo "❌ No response from external IP"
}

# Main execution
main() {
    echo "Starting immediate debug for Internal Server Error..."
    echo ""
    
    check_containers
    check_logs
    check_resources
    check_mounts
    test_container_access
    test_web_response
    
    echo ""
    echo "🎯 SUMMARY & RECOMMENDATIONS:"
    echo "============================"
    echo ""
    echo "Based on the debug results above:"
    echo ""
    echo "1. If containers are not running → Run: docker compose up -d"
    echo "2. If out of disk space → Clean up: docker system prune"
    echo "3. If mount issues → Remount Google Drive"
    echo "4. If container crashes → Check logs for specific errors"
    echo "5. If all else fails → Complete reset with local storage"
    echo ""
    echo "🔧 Quick fixes to try:"
    echo "   docker compose restart"
    echo "   docker compose down && docker compose up -d"
    echo "   docker system prune -f"
}

main "$@"
