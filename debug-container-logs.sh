#!/bin/bash

echo "🔍 DETAILED CONTAINER DEBUG"
echo "==========================="

# Get container ID
CONTAINER=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')

if [ -z "$CONTAINER" ]; then
    echo "❌ No Nextcloud container found"
    exit 1
fi

echo "🐳 Container: $CONTAINER"
echo ""

echo "📋 Full Container Logs:"
echo "======================"
docker logs "$CONTAINER"

echo ""
echo "🔧 Container Environment:"
echo "========================"
docker exec "$CONTAINER" env | grep -E "(NEXTCLOUD|MYSQL|REDIS)" | sort

echo ""
echo "📁 File System Check:"
echo "===================="
echo "HTML directory:"
docker exec "$CONTAINER" ls -la /var/www/html/

echo ""
echo "Config directory:"
docker exec "$CONTAINER" ls -la /var/www/html/config/

echo ""
echo "Data directory:"
docker exec "$CONTAINER" ls -la /var/www/html/data/

echo ""
echo "🔒 Permission Test:"
echo "=================="
echo "Testing www-data write access to config:"
docker exec -u www-data "$CONTAINER" touch /var/www/html/config/test-write 2>&1
docker exec "$CONTAINER" ls -la /var/www/html/config/test-write 2>/dev/null && echo "✅ Write test successful" || echo "❌ Write test failed"
docker exec "$CONTAINER" rm /var/www/html/config/test-write 2>/dev/null

echo ""
echo "🌐 Web Server Status:"
echo "===================="
docker exec "$CONTAINER" ps aux | grep apache

echo ""
echo "�� Network Test:"
echo "==============="
echo "Testing database connection:"
docker exec "$CONTAINER" nc -z db 3306 && echo "✅ DB connection OK" || echo "❌ DB connection failed"

echo ""
echo "Testing Redis connection:"
docker exec "$CONTAINER" nc -z redis 6379 && echo "✅ Redis connection OK" || echo "❌ Redis connection failed"

