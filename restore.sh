#!/bin/bash
if [ -z "$1" ]; then
  echo "❌ Vui lòng nhập tên thư mục backup! Ví dụ: ./restore.sh /home/ubuntu/backups/db_backup_2026..."
  exit 1
fi

BACKUP_PATH=$1
echo "Bắt đầu khôi phục dữ liệu từ $BACKUP_PATH..."

docker exec note-api-db rm -rf /dump_restore
docker cp $BACKUP_PATH note-api-db:/dump_restore
docker exec note-api-db mongorestore --db notedb --drop /dump_restore

echo "✅ Phục hồi dữ liệu thành công!"