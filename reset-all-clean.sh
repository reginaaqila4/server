#!/bin/bash

echo "🔥 COMPLETE RESET - Removing ALL Nextcloud components..."
echo "WARNING: This will delete EVERYTHING (containers, volumes, configs)"
echo ""

read -p "Are you sure you want to COMPLETELY RESET everything? (type 'YES' to confirm): " confirm
if [ "$confirm" != "YES" ]; then
    echo "❌ Reset cancelled"
    exit 1
fi

echo ""
echo "🧹 Starting complete cleanup..."

# 1. Stop and remove all containers
echo "🐳 Stopping and removing Docker containers..."
docker compose down --volumes --remove-orphans 2>/dev/null || true
docker stop $(docker ps -aq --filter "name=nextcloud") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=nextcloud") 2>/dev/null || true

# 2. Remove all volumes
echo "💾 Removing all Docker volumes..."
docker volume rm $(docker volume ls -q | grep nextcloud) 2>/dev/null || true
docker volume prune -f 2>/dev/null || true

# 3. Remove all networks
echo "🌐 Removing Docker networks..."
docker network rm $(docker network ls -q --filter "name=nextcloud") 2>/dev/null || true
docker network prune -f 2>/dev/null || true

# 4. Clean Docker system
echo "🧽 Cleaning Docker system..."
docker system prune -af --volumes 2>/dev/null || true

# 5. Remove Nginx configs
echo "🌐 Removing Nginx configurations..."
sudo rm -f /etc/nginx/sites-enabled/kuromey.eu.org 2>/dev/null || true
sudo rm -f /etc/nginx/sites-available/kuromey.eu.org 2>/dev/null || true
sudo systemctl reload nginx 2>/dev/null || true

# 6. Remove SSL certificates
echo "🔒 Removing SSL certificates..."
sudo rm -rf /etc/letsencrypt/live/kuromey.eu.org 2>/dev/null || true
sudo rm -rf /etc/letsencrypt/archive/kuromey.eu.org 2>/dev/null || true
sudo rm -rf /etc/letsencrypt/renewal/kuromey.eu.org.conf 2>/dev/null || true

# 7. Clean Google Drive mount (keep mount point but clean data)
echo "☁️ Cleaning Google Drive data..."
if mountpoint -q /mnt/gdrive; then
    sudo rm -rf /mnt/gdrive/nextcloud-data/* 2>/dev/null || true
    sudo rm -rf /mnt/gdrive/backup/nextcloud_* 2>/dev/null || true
    echo "✅ Google Drive data cleaned (mount preserved)"
else
    echo "ℹ️  Google Drive not mounted"
fi

# 8. Remove project files (optional)
echo "📁 Project files status:"
echo "   Current directory: $(pwd)"
echo "   Files: $(ls -la | wc -l) items"
echo ""
read -p "Do you want to remove ALL project files too? (y/N): " remove_files
if [[ "$remove_files" =~ ^[Yy]$ ]]; then
    cd ~
    rm -rf ~/nextcloud-server
    echo "✅ Project files removed"
    echo "📋 You need to run the complete tutorial again"
else
    echo "✅ Project files preserved"
fi

echo ""
echo "🎉 Complete reset finished!"
echo ""
echo "✅ Removed:"
echo "   • All Docker containers and volumes"
echo "   • All Docker networks"
echo "   • Nginx configurations"
echo "   • SSL certificates"
echo "   • Google Drive data (files cleaned)"
echo ""
echo "📋 What's preserved:"
echo "   • Google Drive mount (/mnt/gdrive)"
echo "   • Rclone configuration"
echo "   • System packages (Docker, Nginx, etc.)"
if [[ ! "$remove_files" =~ ^[Yy]$ ]]; then
    echo "   • Project files (docker-compose.yml, scripts, etc.)"
fi
echo ""
echo "🚀 Ready for fresh deployment!"
echo "   Run: ./deploy-complete-stable.sh"