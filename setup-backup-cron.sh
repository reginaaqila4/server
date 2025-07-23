#!/bin/bash

echo "⏰ SETUP AUTOMATIC BACKUP EVERY 12 HOURS"
echo "========================================"
echo ""

# Function to setup cron job
setup_cron() {
    echo "📅 Setting up cron job for automatic backup..."
    
    # Create backup script in system location
    sudo cp ~/nextcloud-backup-complete.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/nextcloud-backup-complete.sh
    
    # Create log directory
    sudo mkdir -p /var/log/nextcloud
    sudo chown paperspace:paperspace /var/log/nextcloud
    
    # Add cron job (every 12 hours: 00:00 and 12:00)
    (crontab -l 2>/dev/null; echo "0 0,12 * * * /usr/local/bin/nextcloud-backup-complete.sh --cron >> /var/log/nextcloud/backup.log 2>&1") | crontab -
    
    echo "✅ Cron job added successfully"
    echo "   Schedule: Every 12 hours (00:00 and 12:00)"
    echo "   Log file: /var/log/nextcloud/backup.log"
}

# Function to show cron status
show_cron_status() {
    echo ""
    echo "📋 Current cron jobs:"
    echo "===================="
    crontab -l | grep nextcloud || echo "No Nextcloud backup cron jobs found"
    
    echo ""
    echo "📊 Backup log (last 20 lines):"
    echo "=============================="
    tail -20 /var/log/nextcloud/backup.log 2>/dev/null || echo "No backup log found yet"
}

# Function to test backup manually
test_backup() {
    echo ""
    echo "🧪 Testing backup manually..."
    echo "============================"
    
    if [ -f "/usr/local/bin/nextcloud-backup-complete.sh" ]; then
        echo "Running backup test..."
        /usr/local/bin/nextcloud-backup-complete.sh
    else
        echo "❌ Backup script not found. Run setup first."
    fi
}

# Main menu
main() {
    echo "Choose an option:"
    echo "1. Setup automatic backup (every 12 hours)"
    echo "2. Show cron status and logs"
    echo "3. Test backup manually"
    echo "4. Remove automatic backup"
    echo ""
    read -p "Enter choice (1-4): " choice
    
    case $choice in
        1)
            setup_cron
            show_cron_status
            ;;
        2)
            show_cron_status
            ;;
        3)
            test_backup
            ;;
        4)
            echo "🗑️ Removing automatic backup..."
            crontab -l | grep -v nextcloud | crontab -
            sudo rm -f /usr/local/bin/nextcloud-backup-complete.sh
            echo "✅ Automatic backup removed"
            ;;
        *)
            echo "❌ Invalid choice"
            ;;
    esac
}

main "$@"

