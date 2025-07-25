#!/bin/bash

echo "🔍 QUICK DEBUG - Internal Server Error"
echo "====================================="

# Check container status
echo "📊 Container Status:"
docker ps -a | grep nextcloud

echo ""
echo "📋 App Container Logs:"
CONTAINER=$(docker ps -a | grep nextcloud-.*-app | awk '{print $1}')
if [ -n "$CONTAINER" ]; then
    docker logs "$CONTAINER" --tail 25
else
    echo "❌ No app container found"
fi

echo ""
echo "📁 Mount Status:"
mountpoint /mnt/gdrive && echo "✅ Google Drive mounted" || echo "❌ Google Drive not mounted"

echo ""
echo "🔧 Quick Fixes to Try:"
echo "====================="
echo "1. Restart containers:"
echo "   docker compose restart"
echo ""
echo "2. Check logs in detail:"
echo "   docker logs CONTAINER_ID"
echo ""
echo "3. Reset to minimal setup:"
echo "   docker compose down"
echo "   # Remove Google Drive mount from docker-compose.yml"
echo "   docker compose up -d"
echo ""
echo "4. Check disk space:"
echo "   df -h"

