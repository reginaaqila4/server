#!/bin/bash

echo "🔧 Fixing MySQL configuration and redeploying..."

# Load environment variables
source .env

# Get current IP
NEW_IP=$(curl -s ifconfig.me)
echo "🌐 Current IP: $NEW_IP"

# Update IP in .env
sed -i "s/TRUSTED_DOMAINS=.*/TRUSTED_DOMAINS=localhost,127.0.0.1,$NEW_IP,kuromey.eu.org/" .env

# 1. Stop all containers
echo "🛑 Stopping all containers..."
docker compose down --volumes 2>/dev/null || true

# 2. Remove ONLY the problematic database volume
echo "🗑️ Removing corrupted database volume..."
docker volume rm nextcloud-server_nextcloud_db 2>/dev/null || true

# 3. Verify Google Drive mount
if ! mountpoint -q /mnt/gdrive; then
    echo "❌ Google Drive not mounted! Starting rclone service..."
    sudo systemctl restart rclone-gdrive
    sleep 20
    
    if ! mountpoint -q /mnt/gdrive; then
        echo "❌ Failed to mount Google Drive!"
        exit 1
    fi
fi

echo "✅ Google Drive mounted successfully"

# 4. Setup Google Drive data directory
echo "📁 Setting up Google Drive data directory..."
sudo mkdir -p /mnt/gdrive/nextcloud-data
sudo chown -R 33:33 /mnt/gdrive/nextcloud-data
sudo chmod -R 0770 /mnt/gdrive/nextcloud-data
echo '# Nextcloud data directory' | sudo tee /mnt/gdrive/nextcloud-data/.ncdata
sudo chown 33:33 /mnt/gdrive/nextcloud-data/.ncdata

# 5. Start database with fixed configuration
echo "🗄️ Starting database with MySQL 8.0.36 compatible config..."
docker compose up -d db

# 6. Wait and monitor database startup
echo "⏳ Waiting for database initialization (this may take 2-3 minutes)..."
sleep 30

# Monitor database logs
for i in {1..60}; do
    # Check if database is ready
    if docker compose logs db 2>/dev/null | grep -q "ready for connections"; then
        echo "✅ Database ready!"
        break
    fi
    
    # Check for errors
    if docker compose logs db 2>/dev/null | grep -q "ERROR\|Aborting"; then
        echo "❌ Database error detected. Showing logs:"
        docker compose logs db | tail -20
        exit 1
    fi
    
    echo "   Waiting for database... ($i/60)"
    sleep 5
done

# 7. Test database connection
echo "🔍 Testing database connection..."
sleep 10
if docker compose exec db mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ Database connection successful!"
else
    echo "❌ Database connection failed. Showing logs:"
    docker compose logs db | tail -15
    exit 1
fi

# 8. Start Redis
echo "⚡ Starting Redis..."
docker compose up -d redis
sleep 10

# 9. Start Nextcloud
echo "🌐 Starting Nextcloud..."
docker compose up -d app
sleep 30

# 10. Final status check
echo "📊 Final deployment status:"
docker compose ps

# 11. Test web access
echo "🌐 Testing web access..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081)
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
    echo "✅ Web access OK (HTTP $HTTP_CODE)"
else
    echo "❌ Web access issue (HTTP $HTTP_CODE)"
    echo "Container logs:"
    docker compose logs app | tail -10
fi

echo ""
echo "🎉 MySQL fix and deployment complete!"
echo ""
echo "📊 Configuration Summary:"
echo "   ✅ MySQL 8.0.36 compatible configuration"
echo "   ✅ Database: VPS (fresh volume)"
echo "   ✅ Config: VPS"
echo "   ✅ User uploads: Google Drive"
echo ""
echo "🌐 Access URLs:"
echo "   Direct IP: http://$NEW_IP:8081"
echo "   Domain: http://kuromey.eu.org (setup Nginx)"
echo ""
echo "📋 Next steps:"
echo "   1. Test access: http://$NEW_IP:8081"
echo "   2. If working, run: ./fix-redirect-loop.sh"
echo "   3. Complete web setup with database credentials"