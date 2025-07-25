#!/bin/bash

echo "🚨 EMERGENCY DIAGNOSIS - CONTAINER RESTART ISSUE"
echo "==============================================="

cd /home/paperspace/nextcloud-server

echo "1. CHECKING CONTAINER LOGS..."
echo "================================"
docker compose logs app | tail -30

echo ""
echo "2. CHECKING MOUNT STATUS..."
echo "============================"
mountpoint /mnt/gdrive && echo "✅ Mount OK" || echo "❌ Mount Failed"
df -h | grep gdrive
ls -la /mnt/gdrive/nextcloud-uploads/

echo ""
echo "3. CHECKING DATA DIRECTORY PERMISSIONS..."
echo "========================================"
ls -ld /mnt/gdrive/nextcloud-uploads/
ls -la ./data/nextcloud/ | head -5

echo ""
echo "4. CHECKING CONTAINER STATUS LOOP..."
echo "==================================="
for i in {1..5}; do
    echo "Check $i:"
    docker compose ps app
    sleep 3
done

echo ""
echo "5. CHECKING FOR CONFLICTING PROCESSES..."
echo "======================================="
ps aux | grep nextcloud | grep -v grep || echo "No conflicting processes"

echo ""
echo "6. CHECKING DOCKER SYSTEM..."
echo "==========================="
docker system df
docker info | grep -E "(Storage Driver|Logging Driver|Cgroup Driver)"

echo ""
echo "🎯 DIAGNOSIS COMPLETE"