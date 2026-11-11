# Kiến trúc cuối — Docker Compose

```mermaid
flowchart TD
    User[Trình duyệt] --> SG[AWS Security Group / UFW]
    SG --> Nginx[Nginx trên EC2 :80, TLS khi được cấu hình]
    Nginx --> App[Express trong Docker, host 127.0.0.1:3000]
    App --> DB[MongoDB 6.0, mạng nội bộ Compose]
    DB --> Volume[(mongo_data)]
    Git[GitHub commit / PR] --> Test[API tests + Docker operations tests]
    Test -->|main, tests pass| SSH[SSH checkout đúng commit]
    SSH --> Deploy[Build image SHA → backup → up/wait → smoke]
    Deploy --> App
    Deploy -->|failure| Rollback[Khôi phục application image trước]
    DB --> Backup[Archive + SHA256 ngoài checkout]
    App --> Logs[JSON request logs / Docker log rotation]
    EC2[EC2 metrics] --> CW[CloudWatch: cần xác minh cấu hình AWS]
```

Nginx chạy trên host; Docker quản lý app và DB, thay vai trò PM2 ở tuần 1. `diagram.png` được giữ làm minh chứng lịch sử tuần 1; sơ đồ Mermaid trên là kiến trúc hiện tại.

App chạy user `node`, filesystem chỉ đọc, bỏ Linux capabilities. Chỉ host loopback được publish cổng app; MongoDB không có mapping cổng. Volume lưu dữ liệu qua lần tạo lại container. Tên project mặc định lấy từ thư mục `devops-note-api`, vì vậy không đổi tên project trên EC2 hiện hữu.

Readiness `/health` ping DB và chứa SHA phiên bản. `/live` chỉ phản ánh tiến trình HTTP. Docker dùng readiness để kiểm tra triển khai; trạng thái unhealthy tự nó không làm Docker restart, nên cần monitoring/cảnh báo. Restart policy chỉ phục hồi khi tiến trình dừng, không phải giải pháp cho mọi lỗi tài nguyên.

CI có database riêng cho API test và project Compose riêng cho thử nghiệm có xóa dữ liệu. Pipeline production chỉ kiểm tra đọc HTTP; không cố tình gây lỗi hoặc xóa dữ liệu người dùng.
