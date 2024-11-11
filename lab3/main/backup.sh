#!/bin/sh
CURRENT_DATE=$(date "+%Y-%m-%d_%H:%M:%S")
BACKUP_DIR="$HOME/backups/$CURRENT_DATE"
mkdir -p "$BACKUP_DIR"
pg_basebackup -D "$BACKUP_DIR" -F tar -z -P -p 9644 
ssh postgres1@pg173 "mkdir $HOME/backups/$CURRENT_DATE"
scp "$BACKUP_DIR"/*.tar.gz postgres1@pg173:$HOME/backups/"$BACKUP_DIR"
find $HOME/backups/ -type d -mtime +7 -exec rm -rf {} \;
ssh postgres1@pg173 'find $HOME/backups/ -type d -mtime +28 -exec rm -rf {} \;'
ssh postgres1@pg173 'find $HOME/wal_archive/ -type f -mtime +28 -exec rm -f {} \;'
