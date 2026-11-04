#!/bin/bash
if [ -z "$1" ]; then
  echo "❌ Vui lòng nhập tên thư mục backup!"
  echo "Ví dụ: ./restore.sh /home/ubuntu/backups/db_backup_2026..."
  exit 1
fi

BACKUP_PATH=$1

# Kiểm tra xem thư mục backup có thực sự tồn tại trên máy host không
if [ ! -d "$BACKUP_PATH" ]; then
  echo "❌ LỖI: Không tìm thấy thư mục backup tại đường dẫn: $BACKUP_PATH"
  exit 1
fi

echo "Bắt đầu khôi phục dữ liệu từ $BACKUP_PATH..."

# Xóa rác cũ trong container nếu có
docker exec note-api-db rm -rf /dump_restore

# Copy thư mục backup (chứa folder notedb) vào trong container
docker cp $BACKUP_PATH note-api-db:/dump_restore

# Chạy restore trỏ thẳng vào thư mục /dump_restore/notedb để tránh lỗi "--db deprecated"
docker exec note-api-db mongorestore --drop /dump_restore/notedb

echo "✅ Phục hồi dữ liệu hoàn tất!"