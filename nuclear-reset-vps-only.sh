#!/bin/bash

echo "🔥 NUCLEAR RESET - VPS DOCKER ONLY (TIDAK SENTUH GOOGLE DRIVE)"
echo "⚠️  Script ini hanya menghapus Docker data di VPS"
echo "📁 Google Drive TIDAK akan disentuh sama sekali"
echo ""
read -p "Lanjutkan? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Dibatalkan"
    exit 1
fi

echo ""
echo "🛑 STEP 1: STOP SEMUA CONTAINER"
docker compose down 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true

echo ""
echo "🗑️  STEP 2: HAPUS SEMUA CONTAINER"
docker rm $(docker ps -aq) 2>/dev/null || true

echo ""
echo "🗑️  STEP 3: HAPUS SEMUA DOCKER VOLUMES NEXTCLOUD"
echo "📋 Volume yang akan dihapus:"
docker volume ls | grep -E "(nextcloud|server)" | awk '{print $2}'

# Hapus semua volume yang mengandung nextcloud atau server
docker volume ls | grep -E "(nextcloud|server)" | awk '{print $2}' | xargs -r docker volume rm 2>/dev/null || true

echo ""
echo "🗑️  STEP 4: HAPUS SEMUA DOCKER NETWORKS"
docker network ls | grep -v "bridge\|host\|none" | awk 'NR>1 {print $1}' | xargs -r docker network rm 2>/dev/null || true

echo ""
echo "🗑️  STEP 5: CLEAN DOCKER SYSTEM"
docker system prune -af --volumes

echo ""
echo "📁 STEP 6: CLEAN PROJECT FILES (KECUALI RCLONE CONFIG)"
# Backup rclone config dulu
if [ -d "rclone" ]; then
    cp -r rclone /tmp/rclone-backup
    echo "✅ Rclone config di-backup ke /tmp/rclone-backup"
fi

# Hapus semua file kecuali yang penting
find . -name "*.sh" -delete 2>/dev/null || true
find . -name "docker-compose.yml*" -delete 2>/dev/null || true
find . -name ".env*" -delete 2>/dev/null || true
rm -rf php-config mysql-config 2>/dev/null || true

# Restore rclone config
if [ -d "/tmp/rclone-backup" ]; then
    cp -r /tmp/rclone-backup rclone
    rm -rf /tmp/rclone-backup
    echo "✅ Rclone config di-restore"
fi

echo ""
echo "🔍 STEP 7: VERIFIKASI CLEANUP"
echo "📊 Docker volumes tersisa:"
docker volume ls
echo ""
echo "📊 Docker containers tersisa:"
docker ps -a
echo ""
echo "📊 Files tersisa di project:"
ls -la

echo ""
echo "✅ NUCLEAR RESET VPS SELESAI!"
echo ""
echo "📋 Yang sudah dibersihkan:"
echo "   ✓ Semua Docker containers"
echo "   ✓ Semua Docker volumes (database, config, html)"
echo "   ✓ Semua Docker networks"
echo "   ✓ Semua project files kecuali rclone config"
echo ""
echo "📋 Yang TIDAK disentuh:"
echo "   ✓ Google Drive mount (/mnt/gdrive)"
echo "   ✓ File di Google Drive"
echo "   ✓ Rclone config"
echo ""
echo "🚀 Siap untuk deploy fresh installation!"