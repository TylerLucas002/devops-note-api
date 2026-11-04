#!/bin/bash
if [ -z "$1" ]; then
  echo "❌ Vui lòng nhập tên thư mục backup!"
  exit 1
fi

BACKUP_PATH=$1

if [ ! -d "$BACKUP_PATH" ]; then
  echo "❌ LỖI: Không tìm thấy thư mục backup tại đường dẫn: $BACKUP_PATH"
  exit 1
fi

echo "Bắt đầu khôi phục dữ liệu từ $BACKUP_PATH..."

# Xóa thư mục tạm cũ trong container để tránh chồng chéo dữ liệu
docker exec note-api-db rm -rf /dump_restore

# Copy nội dung thư mục backup vào container
docker cp "$BACKUP_PATH" note-api-db:/dump_restore

# Chạy restore quét tự động toàn bộ thư mục (không ép cứng tên database)
docker exec note-api-db mongorestore --drop /dump_restore

echo "✅ Phục hồi dữ liệu hoàn tất!"