#!/bin/bash

echo "🔍 Nextcloud Diagnostic Script"
echo "==============================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

check_item() {
    local item="$1"
    local command="$2"
    local fix_hint="$3"
    
    echo -n "Checking $item... "
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAIL${NC}"
        if [ -n "$fix_hint" ]; then
            echo -e "   ${YELLOW}Fix: $fix_hint${NC}"
        fi
        return 1
    fi
    return 0
}

echo "🐳 Docker Status:"
check_item "Docker installed" "command -v docker" "Install with: curl -fsSL https://get.docker.com | sh"
check_item "Docker running" "sudo systemctl is-active docker" "Start with: sudo systemctl start docker"
check_item "Docker compose" "command -v docker-compose || docker compose version" "Install docker compose plugin"

echo ""
echo "☁️ Google Drive Mount:"
check_item "Mount point exists" "[ -d /mnt/gdrive ]" "Create with: sudo mkdir -p /mnt/gdrive"
check_item "Google Drive mounted" "mountpoint -q /mnt/gdrive" "Mount with rclone"
check_item "Config folder exists" "[ -d /mnt/gdrive/config ]" "Create with: sudo mkdir -p /mnt/gdrive/config"
check_item "Data folder exists" "[ -d /mnt/gdrive/data ]" "Create with: sudo mkdir -p /mnt/gdrive/data"

echo ""
echo "📁 Permissions Check:"
if [ -d "/mnt/gdrive/config" ]; then
    CONFIG_OWNER=$(stat -c '%U:%G' /mnt/gdrive/config 2>/dev/null || echo "unknown")
    CONFIG_PERMS=$(stat -c '%a' /mnt/gdrive/config 2>/dev/null || echo "unknown")
    echo "Config ownership: $CONFIG_OWNER (should be www-data:www-data or 33:33)"
    echo "Config permissions: $CONFIG_PERMS (should be 770)"
fi

if [ -d "/mnt/gdrive/data" ]; then
    DATA_OWNER=$(stat -c '%U:%G' /mnt/gdrive/data 2>/dev/null || echo "unknown")
    DATA_PERMS=$(stat -c '%a' /mnt/gdrive/data 2>/dev/null || echo "unknown")
    echo "Data ownership: $DATA_OWNER (should be www-data:www-data or 33:33)"
    echo "Data permissions: $DATA_PERMS (should be 770)"
fi

echo ""
echo "🐳 Container Status:"
if command -v docker >/dev/null 2>&1; then
    CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(nextcloud|redis|mysql|db)" || echo "No Nextcloud containers found")
    echo "$CONTAINERS"
else
    echo "Docker not available"
fi

echo ""
echo "📝 Config File Status:"
if [ -f "/mnt/gdrive/config/config.php" ]; then
    CONFIG_SIZE=$(stat -c %s /mnt/gdrive/config/config.php)
    CONFIG_OWNER=$(stat -c '%U:%G' /mnt/gdrive/config/config.php)
    CONFIG_PERMS=$(stat -c '%a' /mnt/gdrive/config/config.php)
    
    echo "✅ Config file exists"
    echo "   Size: $CONFIG_SIZE bytes"
    echo "   Owner: $CONFIG_OWNER"
    echo "   Permissions: $CONFIG_PERMS"
    
    if [ "$CONFIG_SIZE" -lt 100 ]; then
        echo -e "   ${RED}⚠️  File too small, possibly corrupt${NC}"
    fi
    
    if grep -q "trusted_domains" /mnt/gdrive/config/config.php; then
        echo "   ✅ Contains trusted_domains"
    else
        echo -e "   ${YELLOW}⚠️  No trusted_domains found${NC}"
    fi
    
else
    echo -e "${RED}❌ Config file does not exist${NC}"
fi

echo ""
echo "🌐 Network Check:"
if command -v docker >/dev/null 2>&1; then
    NEXTCLOUD_PORT=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep nextcloud | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2 || echo "Not found")
    if [ "$NEXTCLOUD_PORT" != "Not found" ]; then
        echo "✅ Nextcloud accessible on port: $NEXTCLOUD_PORT"
        echo "   URL: http://$(hostname -I | awk '{print $1}'):$NEXTCLOUD_PORT"
    else
        echo "❌ Nextcloud port not found"
    fi
fi

echo ""
echo "📋 Quick Fixes:"
echo "=================="
echo "1. Fix permissions:"
echo "   sudo chown -R 33:33 /mnt/gdrive/config /mnt/gdrive/data"
echo "   sudo chmod -R 0770 /mnt/gdrive/config /mnt/gdrive/data"
echo ""
echo "2. Remove corrupt config:"
echo "   sudo rm /mnt/gdrive/config/config.php"
echo ""
echo "3. Restart containers:"
echo "   cd ~/nextcloud-server && docker compose restart"
echo ""
echo "4. Fresh install:"
echo "   cd ~/nextcloud-server && docker compose down && docker compose up -d"

