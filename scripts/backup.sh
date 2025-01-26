#!/bin/bash

# Configuration
BACKUP_DIR="/backup"
MONGODB_URI="$MONGODB_URI"
BACKUP_COUNT=7  # Keep last 7 days of backups

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to perform backup
perform_backup() {
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"
    
    echo "Starting backup at $TIMESTAMP"
    
    # Perform mongodump
    mongodump --uri="$MONGODB_URI" --out="$BACKUP_PATH"
    
    if [ $? -eq 0 ]; then
        echo "Backup completed successfully"
        # Create compressed archive
        cd "$BACKUP_DIR"
        tar -czf "backup_$TIMESTAMP.tar.gz" "backup_$TIMESTAMP"
        rm -rf "backup_$TIMESTAMP"
        
        # Rotate old backups
        ls -t "$BACKUP_DIR"/backup_*.tar.gz | tail -n +$((BACKUP_COUNT + 1)) | xargs -r rm
    else
        echo "Backup failed"
        exit 1
    fi
}

# Function to check MongoDB connection
check_mongodb() {
    mongo --uri="$MONGODB_URI" --eval "db.adminCommand('ping')" > /dev/null
    return $?
}

# Main backup loop
while true; do
    # Wait for MongoDB to be ready
    until check_mongodb; do
        echo "Waiting for MongoDB to be ready..."
        sleep 5
    done
    
    # Perform backup
    perform_backup
    
    # Sleep until next backup (using BACKUP_CRON if set, otherwise daily)
    if [ -n "$BACKUP_CRON" ]; then
        # Calculate next run based on cron expression
        next_run=$(date -d "$(cronplan "$BACKUP_CRON" | head -n1)" +%s)
        now=$(date +%s)
        sleep_seconds=$((next_run - now))
        sleep $sleep_seconds
    else
        # Default: sleep for 24 hours
        sleep 86400
    fi
done 