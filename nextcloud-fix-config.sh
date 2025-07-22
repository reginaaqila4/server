#!/bin/bash

echo "🔧 Nextcloud Configuration Fix Script"
echo "====================================="

# Function to check if running as proper user
check_user() {
    if [ "$EUID" -eq 0 ]; then
        echo "❌ Jangan jalankan script ini sebagai root!"
        echo "   Gunakan user paperspace atau user biasa"
        exit 1
    fi
    echo "✅ Running as user: $(whoami)"
}

# Function to check Docker installation and containers
check_docker() {
    echo ""
    echo "🐳 Checking Docker Status..."
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker tidak terinstall!"
        echo "   Install Docker terlebih dahulu"
        return 1
    fi
    
    echo "✅ Docker installed"
    
    # Check if containers are running
    if ! docker ps | grep -q nextcloud; then
        echo "❌ Nextcloud container tidak berjalan!"
        echo "   Jalankan: docker compose up -d"
        return 1
    fi
    
    echo "✅ Nextcloud containers running"
    docker ps | grep -E "(nextcloud|redis|mysql|db)"
}

# Function to check Google Drive mount
check_gdrive_mount() {
    echo ""
    echo "☁️ Checking Google Drive Mount..."
    
    if ! mountpoint -q /mnt/gdrive; then
        echo "❌ Google Drive tidak ter-mount!"
        echo "   Mount ulang Google Drive terlebih dahulu"
        return 1
    fi
    
    echo "✅ Google Drive mounted"
    
    # Check permissions
    if [ ! -d "/mnt/gdrive/data" ] || [ ! -d "/mnt/gdrive/config" ]; then
        echo "⚠️  Folder data/config tidak ada di Google Drive"
        echo "   Membuat folder..."
        sudo mkdir -p /mnt/gdrive/data /mnt/gdrive/config
        sudo chown -R 33:33 /mnt/gdrive/data /mnt/gdrive/config
        sudo chmod -R 0770 /mnt/gdrive/data /mnt/gdrive/config
    fi
    
    echo "✅ Data and config folders exist"
}

# Function to fix config.php permissions
fix_config_permissions() {
    echo ""
    echo "🔒 Fixing Config Permissions..."
    
    # Get the container name
    CONTAINER_NAME=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    
    if [ -z "$CONTAINER_NAME" ]; then
        echo "❌ Nextcloud app container tidak ditemukan!"
        return 1
    fi
    
    echo "✅ Found container: $CONTAINER_NAME"
    
    # Check if config.php exists
    if [ -f "/mnt/gdrive/config/config.php" ]; then
        echo "📝 Config.php found, checking permissions..."
        
        # Fix ownership and permissions
        sudo chown 33:33 /mnt/gdrive/config/config.php
        sudo chmod 0660 /mnt/gdrive/config/config.php
        
        echo "✅ Fixed config.php permissions"
        
        # Show current permissions
        ls -la /mnt/gdrive/config/config.php
        
        # Backup current config
        cp /mnt/gdrive/config/config.php /mnt/gdrive/config/config.php.backup.$(date +%Y%m%d_%H%M%S)
        echo "✅ Backup created"
        
    else
        echo "⚠️  Config.php tidak ada, akan dibuat ulang saat restart"
    fi
    
    # Fix all config directory permissions
    sudo chown -R 33:33 /mnt/gdrive/config
    sudo chmod -R 0770 /mnt/gdrive/config
    
    # Fix data directory permissions  
    sudo chown -R 33:33 /mnt/gdrive/data
    sudo chmod -R 0770 /mnt/gdrive/data
    
    echo "✅ All permissions fixed"
}

echo "Script created successfully. Run with: bash nextcloud-fix-config.sh"

# Function to restart Nextcloud properly
restart_nextcloud() {
    echo ""
    echo "🔄 Restarting Nextcloud..."
    
    # Get project directory
    PROJECT_DIR=$(find ~ -name "docker-compose.yml" -path "*/nextcloud*" -exec dirname {} \; 2>/dev/null | head -1)
    
    if [ -z "$PROJECT_DIR" ]; then
        echo "❌ Project directory tidak ditemukan!"
        echo "   Pastikan Anda di directory yang benar"
        return 1
    fi
    
    echo "✅ Found project dir: $PROJECT_DIR"
    
    cd "$PROJECT_DIR"
    
    # Stop containers
    echo "🛑 Stopping containers..."
    docker compose down
    
    # Wait a moment
    sleep 3
    
    # Start containers
    echo "🚀 Starting containers..."
    docker compose up -d
    
    # Wait for startup
    echo "⏳ Waiting for startup..."
    sleep 10
    
    # Check status
    docker compose ps
}

# Function to run Nextcloud maintenance commands
run_maintenance() {
    echo ""
    echo "🔧 Running Nextcloud Maintenance..."
    
    CONTAINER_NAME=$(docker ps | grep nextcloud-.*-app | awk '{print $1}')
    
    if [ -z "$CONTAINER_NAME" ]; then
        echo "❌ Container tidak berjalan!"
        return 1
    fi
    
    echo "🔄 Running maintenance mode..."
    docker exec -u www-data "$CONTAINER_NAME" php occ maintenance:mode --on
    
    echo "🔄 Checking config..."
    docker exec -u www-data "$CONTAINER_NAME" php occ config:list system --private
    
    echo "🔄 Repair database..."
    docker exec -u www-data "$CONTAINER_NAME" php occ db:add-missing-indices
    docker exec -u www-data "$CONTAINER_NAME" php occ db:add-missing-columns
    
    echo "🔄 Update htaccess..."
    docker exec -u www-data "$CONTAINER_NAME" php occ maintenance:update:htaccess
    
    echo "🔄 Turning off maintenance mode..."
    docker exec -u www-data "$CONTAINER_NAME" php occ maintenance:mode --off
    
    echo "✅ Maintenance completed"
}

# Function to show config status
show_config_status() {
    echo ""
    echo "📋 Configuration Status:"
    echo "========================"
    
    if [ -f "/mnt/gdrive/config/config.php" ]; then
        echo "✅ Config file exists"
        echo "📁 Location: /mnt/gdrive/config/config.php"
        echo "�� Permissions: $(ls -la /mnt/gdrive/config/config.php | awk '{print $1, $3, $4}')"
        echo "📊 Size: $(ls -lh /mnt/gdrive/config/config.php | awk '{print $5}')"
        
        # Show trusted domains
        echo ""
        echo "🌐 Trusted Domains:"
        if grep -q "trusted_domains" /mnt/gdrive/config/config.php; then
            grep -A 10 "trusted_domains" /mnt/gdrive/config/config.php | head -10
        else
            echo "   No trusted domains found"
        fi
    else
        echo "❌ Config file tidak ada!"
    fi
    
    echo ""
    echo "📂 Directory Structure:"
    ls -la /mnt/gdrive/ | grep -E "(config|data)"
}

# Main execution
main() {
    echo "Starting Nextcloud configuration fix..."
    
    check_user
    
    if check_docker && check_gdrive_mount; then
        fix_config_permissions
        restart_nextcloud
        sleep 15
        run_maintenance
        show_config_status
        
        echo ""
        echo "🎉 Configuration fix completed!"
        echo ""
        echo "📌 Next Steps:"
        echo "1. Akses Nextcloud di browser: http://YOUR_IP:8081"
        echo "2. Jika masih error, coba install ulang dari web interface"
        echo "3. Jika perlu, edit trusted domains manually"
        echo ""
        echo "🔍 Useful Commands:"
        echo "- Check logs: docker compose logs -f app"
        echo "- Shell access: docker exec -it \$(docker ps | grep nextcloud | awk '{print \$1}') bash"
        echo "- Maintenance: docker exec -u www-data CONTAINER php occ maintenance:mode --on/off"
        
    else
        echo ""
        echo "❌ Prerequisites tidak terpenuhi!"
        echo "   Pastikan Docker dan Google Drive mount sudah siap"
        echo ""
        echo "📋 Checklist:"
        echo "1. ✅ Install Docker: curl -fsSL https://get.docker.com | sh"
        echo "2. ✅ Mount Google Drive dengan rclone"
        echo "3. ✅ Jalankan docker compose up -d"
        echo "4. ✅ Jalankan script ini lagi"
    fi
}

# Run main function
main "$@"
