#!/bin/bash

echo "🔄 FORCE FRESH NEXTCLOUD SETUP"
echo "⚠️  Script ini akan menghapus data instalasi Nextcloud"
echo "📁 HANYA menghapus: config, html volumes"
echo "🗄️  Database dan Google Drive TIDAK disentuh"
echo ""

echo "📋 Current status:"
docker compose ps

echo ""
read -p "Lanjutkan force fresh setup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Dibatalkan"
    exit 1
fi

echo ""
echo "🛑 STEP 1: STOP CONTAINERS"
docker compose down

echo ""
echo "🗑️  STEP 2: REMOVE NEXTCLOUD INSTALLATION VOLUMES"
echo "📋 Volumes yang akan dihapus:"
docker volume ls | grep -E "nextcloud.*_(config|html)" | awk '{print $2}'

# Hapus volume config dan html saja (biar setup wizard muncul)
docker volume ls | grep -E "nextcloud.*_config" | awk '{print $2}' | xargs -r docker volume rm
docker volume ls | grep -E "nextcloud.*_html" | awk '{print $2}' | xargs -r docker volume rm

echo "✅ Installation volumes removed"

echo ""
echo "🔄 STEP 3: RESTART CONTAINERS"
echo "🔄 Starting database..."
docker compose up -d db
echo "⏳ Waiting for database..."
sleep 15

echo "🔄 Starting Redis..."
docker compose up -d redis
sleep 5

echo "🔄 Starting Nextcloud app..."
docker compose up -d app
echo "⏳ Waiting for Nextcloud to initialize..."
sleep 30

echo ""
echo "🔧 STEP 4: VERIFY SETUP"
echo "📊 Container status:"
docker compose ps

echo ""
echo "🌐 Testing web access..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Web access OK (HTTP $HTTP_CODE)"
else
    echo "❌ Web access failed (HTTP $HTTP_CODE)"
fi

echo ""
echo "🎉 FRESH SETUP READY!"
echo ""
echo "📋 Yang dihapus:"
echo "   ✓ nextcloud_config volume (instalasi data)"
echo "   ✓ nextcloud_html volume (aplikasi data)"
echo ""
echo "📋 Yang dipertahankan:"
echo "   ✓ nextcloud_db volume (database tetap ada)"
echo "   ✓ Google Drive data (/mnt/gdrive/nextcloud-uploads)"
echo "   ✓ Apps dan themes volumes"
echo ""
echo "🌐 Akses setup wizard:"
echo "   http://$(curl -s ifconfig.me):8081"
echo ""
echo "🗄️  Database info untuk setup wizard:"
echo "   Database: MySQL/MariaDB"
echo "   Host: db"
echo "   Database name: nextcloud"
echo "   Username: nextclouduser"
echo "   Password: Nextcloud123!"
echo ""
echo "📁 Data folder: /var/www/html/data (JANGAN UBAH)"