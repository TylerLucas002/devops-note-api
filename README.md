# DevOps Final Project: Smart Note API

**Môn học:** DevOps - Học kỳ 2026
**Nhóm:** Làng Xì Mi
**Thành viên:**
1. **Nguyễn Bá Toàn:** Thiết kế kiến trúc hạ tầng, thiết lập Server Ubuntu, cấu hình UFW Firewall và Nginx.
2. **Trần Tiến Minh:** Xây dựng backend Node.js (Express), kết nối và cấu hình mô hình dữ liệu, viết Automated Test.
3. **Hồ Thăng Bảo Huy:** Cài đặt MongoDB, thiết lập PM2, cấu hình Git repo và kiểm thử bằng Postman.

---

## Hướng dẫn triển khai thủ công
1. Clone source code: `git clone <repository_url>`
2. Cài đặt các dependencies: `sudo apt install nginx mongodb` và Node.js.
3. Vào thư mục dự án chạy: `npm install`
4. Khởi chạy ứng dụng: `pm2 start server.js --name note-api`
5. Cấu hình Nginx proxy_pass về `localhost:3000` và khởi động lại Nginx.

---

## Hướng dẫn triển khai bằng Docker & CI/CD

Từ Tuần 2, hệ thống đã được container hóa và tự động hóa quá trình kiểm thử, triển khai.

### 1. Triển khai bằng Docker (Containerization)
Thay vì chạy trực tiếp trên máy chủ bằng PM2, hệ thống hiện được đóng gói hoàn toàn bằng Docker, bao gồm cả Database với Volume lưu trữ dữ liệu vĩnh viễn (Persistence).
- Khởi chạy toàn bộ hệ thống (App + MongoDB):
  ```bash
  sudo docker compose up -d --build
  ```
- Dừng hệ thống:
  ```bash
  sudo docker compose down
  ```

### 2. Luồng tự động hóa CI/CD (GitHub Actions)
Pipeline được định nghĩa tại file `.github/workflows/deploy.yml` và tự động kích hoạt khi có thay đổi (push/merge) vào nhánh `main`. Quy trình gồm 2 bước (Jobs):
- **Test (Kiểm thử):** GitHub Actions khởi tạo môi trường Node.js và một dịch vụ MongoDB bản 6.0 để chạy môi trường ảo. Lệnh `npm test` được thực thi để kiểm thử các API. Nếu bài test thất bại, pipeline sẽ tự động bị chặn lại (Fail) để ngăn code lỗi lên Server.
- **Deploy (Triển khai):** Nếu bước Test vượt qua thành công (Pass), hệ thống tự động đăng nhập vào máy chủ AWS EC2 thông qua SSH, đồng bộ bộ code mới nhất (`git fetch` & `git reset --hard`) và chạy lệnh cập nhật Docker Compose để áp dụng bản release mới mà không cần thao tác thủ công.

### 3. Yêu cầu cấu hình GitHub Secrets
Để tiến trình Deploy tự động hoạt động, kho lưu trữ (Repository) cần được thiết lập các biến môi trường bí mật (Secrets) sau:
- `SERVER_HOST`: Địa chỉ IP Public của máy chủ AWS EC2.
- `SERVER_USER`: Tên người dùng SSH (mặc định: `ubuntu`).
- `SERVER_SSH_KEY`: Nội dung toàn bộ khóa bí mật (`.pem`) dùng để kết nối SSH.

## Tài liệu và minh chứng

- [Kiến trúc hệ thống](docs/architecture/README.md) và [sơ đồ](docs/architecture/diagram.png).
- [Báo cáo tuần 1](docs/week-1/README.md) và [ảnh minh chứng](evidence/week-1/).
- Tuần 2: [Deploy tự động](docs/week-2/automated-deployment.md), [lưu dữ liệu](docs/week-2/database-persistence.md), [pipeline lỗi](docs/week-2/fail-pipeline.md) và [ảnh minh chứng](evidence/week-2/).
- [Playbook vận hành tuần 3](docs/playbook.md), [script sao lưu](scripts/backup.sh) và [script khôi phục](scripts/restore.sh).
