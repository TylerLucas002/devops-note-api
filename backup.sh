#!/bin/bash
# Lưu backup ra ngoài thư mục dự án để không bị Git theo dõi nhầm
BACKUP_DIR="/home/ubuntu/backups"
mkdir -p $BACKUP_DIR
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="$BACKUP_DIR/db_backup_$TIMESTAMP"

echo "Bắt đầu backup database mongod..."
docker exec note-api-db mongodump --db notedb --out /dump
docker cp note-api-db:/dump/notedb $BACKUP_PATH

echo "✅ Backup thành công! Dữ liệu lưu tại: $BACKUP_PATH"