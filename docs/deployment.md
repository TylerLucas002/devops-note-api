# Deployment guide — Ubuntu 24.04 sạch

## 1. Máy chủ và mạng

Dùng EC2 Ubuntu trong `ap-southeast-2`, kiến trúc x86_64 có AVX để chạy MongoDB 6.0. Khuyến nghị ít nhất 2 GB RAM và 16 GB disk cho build tại host. Đối chiếu chi phí trước khi đổi loại máy. Không cần nâng cấp máy hiện có nếu đủ tài nguyên.

Security Group: HTTP 80 từ người dùng; SSH 22 giới hạn nguồn quản trị và runner hợp lệ. Không mở 27017 hoặc 3000 ra Internet. GitHub-hosted runner có IP thay đổi; dùng self-hosted runner hoặc cơ chế quản lý allowlist nếu cần giới hạn SSH chặt. Không vô tình khóa phiên SSH hiện tại. Để có HTTPS cần domain trỏ tới EC2, certificate hợp lệ và cấu hình TLS riêng; mở 443 không có nghĩa đã bật TLS.

## 2. Cài gói

SSH bằng tài khoản `ubuntu`:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git nginx python3 util-linux
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' "$(dpkg --print-architecture)" "$VERSION_CODENAME" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker nginx
sudo docker compose version
```

Yêu cầu Compose có `up --wait` và `--wait-timeout`. App Node chạy trong image; host không cần cài Node/PM2/MongoDB. Server cũ dùng PM2: xác minh và dừng riêng tiến trình `note-api` chiếm cổng 3000 trước khi chuyển Docker.

## 3. Clone và chạy đúng phiên bản

Giữ đường dẫn `/home/ubuntu/devops-note-api` để volume Compose hiện hữu không đổi tên. Với server mới:

```bash
cd /home/ubuntu
git clone https://github.com/batoannguyen52-debug/devops-note-api.git
cd devops-note-api
cp .env.example .env
chmod 600 .env
sudo bash scripts/deploy.sh "$(git rev-parse HEAD)"
```

Server đã chạy: workflow fetch và checkout đúng SHA rồi gọi deploy.sh. Script build image gắn SHA, backup DB nếu đã có DB, cập nhật stack và kiểm tra `/health`, `/notes`, `/`. Chỉ sau kiểm tra thành công mới ghi image/version vào `.env`. Dùng `sudo docker compose ...` và `sudo bash scripts/...` nhất quán trên host nếu `.env` được root tạo.

Không gọi `docker compose down` trước build. Volume cũ được giữ. Lần đầu cập nhật cấu hình Compose có thể tạo lại DB container; phải có backup và chấp nhận gián đoạn ngắn.

## 4. Nginx

```bash
sudo cp config/nginx.conf /etc/nginx/sites-available/note-api
sudo ln -sfn /etc/nginx/sites-available/note-api /etc/nginx/sites-enabled/note-api
# Chỉ bỏ default site trên server dành riêng cho dự án này:
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
curl -f http://localhost/health
```

Cấu hình mẫu dùng cổng 3000; nếu đổi `APP_PORT`, sửa `proxy_pass` tương ứng. Kiểm tra UFW và SG hiện hữu trước khi sửa. Trên server mới dành riêng cho dự án:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
sudo ufw status verbose
```

## 5. GitHub Actions

Repository → Settings → Secrets and variables → Actions: tạo `SERVER_HOST`, `SERVER_USER=ubuntu`, `SERVER_SSH_KEY`. Không ghi private key vào README hoặc ảnh. SSH user phải đọc/ghi checkout và chạy `sudo` không tương tác như luồng triển khai hiện tại.

Push `main` kích hoạt test + operations rồi deploy. Đối chiếu commit SHA trên trang Actions với `version` từ `curl http://PUBLIC_IP/health`. Download artifact `operations-evidence` để xem log backup/restore và ba sự cố. Đây là thực nghiệm CI độc lập, không phải log sự cố production.

## 6. Backup và cron

```bash
sudo bash scripts/backup.sh
sudo install -m 0644 config/backup.cron /etc/cron.d/note-api-backup
sudo ls -lt /home/ubuntu/backups
```

Bản backup gồm `.archive.gz` và `.sha256`, quyền riêng tư. Cron chạy 02:00 theo timezone host (`timedatectl` để kiểm tra). Theo dõi log và dung lượng; sao chép bản backup ra máy/volume khác theo chính sách của nhóm. Backup trên cùng EC2 chưa bảo vệ trước mất toàn bộ instance/disk. Cần xoay vòng có kiểm soát, không xóa bản duy nhất đã xác minh.

## 7. Restore và rollback

Restore ghi đè collection có trong archive. Chọn đúng backup, chấp nhận thời gian app dừng và thử trên staging trước:

```bash
sudo env CONFIRM_RESTORE=yes bash scripts/restore.sh /home/ubuntu/backups/FILE.archive.gz
sudo bash scripts/smoke-test.sh
```

Script kiểm tra checksum, xác minh DB, dừng app để tránh ghi đồng thời, restore và chờ app healthy. Nếu lỗi, script cố bật app lại và trả mã lỗi. Dữ liệu được xác minh bằng test đọc lại ID/nội dung, không chỉ dòng thông báo. Archive mới khác định dạng thư mục dump tuần 3; backup cũ cần quy trình `mongorestore` thủ công trong môi trường thử nghiệm.

Deploy tự thử rollback image khi lỗi health/smoke. Rollback này không tự hoàn tác schema hoặc mọi thay đổi cấu hình DB/Nginx. Kiểm tra log `ROLLBACK FAILED` nếu không phục hồi được. Rollback thủ công tới commit đã kiểm chứng:

```bash
git fetch origin
# Thay SHA_GOOD bằng SHA đầy đủ đã triển khai thành công:
git checkout --detach SHA_GOOD
sudo bash scripts/deploy.sh SHA_GOOD
```

Chỉ dùng deploy.sh trên commit có script này. Với bản cũ hơn, cần dùng image cũ đã lưu và cấu hình tương thích. Sau rollback, xác minh web và ghi nhận SHA đang phục vụ.

## 8. Kiểm tra cuối

```bash
sudo docker compose ps
sudo docker compose logs --tail 30 app
sudo bash scripts/smoke-test.sh http://localhost
sudo ss -lntp
sudo nginx -t
```

Chạy lại hướng dẫn trên một máy sạch khác để xác nhận khả năng tái tạo; kiểm thử Docker trong CI không thay thế kiểm tra toàn bộ Ubuntu/Nginx/AWS.
