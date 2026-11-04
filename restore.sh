#!/bin/bash
if [ -z "$1" ]; then
  echo "❌ Vui lòng nhập tên thư mục backup!"
  exit 1
fi

# TÊN DATABASE TRONG CODE WEB CỦA BẠN (Thường là test, notedb, hoặc note_api)
DB_NAME="notedb"

BACKUP_PATH=$1

if [ ! -d "$BACKUP_PATH" ]; then
  echo "❌ LỖI: Không tìm thấy thư mục backup tại đường dẫn: $BACKUP_PATH"
  exit 1
fi

echo "Bắt đầu khôi phục dữ liệu vào database: $DB_NAME..."

# 1. Xóa dữ liệu tạm cũ trong container
docker exec note-api-db rm -rf /dump_restore

# 2. Tạo thư mục mang tên Database chuẩn cho mongorestore
docker exec note-api-db mkdir -p /dump_restore/$DB_NAME

# 3. Copy các file bson vào chui vào ĐÚNG thư mục của database đó (lưu ý dấu /. ở cuối)
docker cp "$BACKUP_PATH"/. note-api-db:/dump_restore/$DB_NAME/

# 4. Chạy lệnh restore (MongoDB sẽ tự hiểu và đổ vào đúng DB)
docker exec note-api-db mongorestore --drop /dump_restore

echo "✅ Phục hồi dữ liệu hoàn tất!"