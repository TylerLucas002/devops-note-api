# Sổ tay Khắc phục sự cố (Troubleshooting Playbook)

Mỗi sự cố được xử lý theo quy trình: **Triệu chứng → Xác minh → Nguyên nhân → Khắc phục → Phòng tránh**.

Các lệnh trong tài liệu này được mặc định chạy trên **máy chủ AWS EC2 (Ubuntu)**, trong thư mục **`~/devops-note-api`** (trừ khi có ghi chú khác).

---

## 1. Triage (Chẩn đoán nhanh)

Các bước kiểm tra tổng quan khi hệ thống có dấu hiệu bất thường:

### Kiểm tra dịch vụ/container:

```bash
# Kiểm tra trạng thái các container (note-api-app, note-api-db)
docker ps -a
docker compose ps

# Kiểm tra Reverse Proxy Nginx và tài nguyên hệ thống
sudo systemctl status nginx --no-pager
df -h
free -m
```

### Kiểm tra endpoint/healthcheck:

```bash
# Kiểm tra trực tiếp API backend trên port 3000 và qua Nginx (port 80)
curl -i http://localhost:3000/health
curl -i http://localhost/health

# Kiểm tra truy vấn dữ liệu thực tế từ MongoDB
curl -i http://localhost:3000/notes

# Kiểm tra các port đang lắng nghe (80, 3000)
ss -tulpn | grep -E '80|3000'
```

### Ma trận phân loại sự cố:

| Trạng thái Container / Dịch vụ (`docker ps`, `nginx`) | Trạng thái Endpoint / Hạ tầng (`curl`, `df`, CloudWatch) | Ý nghĩa / Tình trạng hệ thống | Chuyển đến mục |
|---|---|---|---|
| `note-api-app`, `note-api-db`, `nginx` đều `Up` / `active` | `GET /health` và `GET /notes` trả về `200 OK` | Hệ thống hoạt động bình thường | — |
| `note-api-db` không chạy (`Exited` / `Restarting`) | `GET /health` trả về `200`, `GET /notes` lỗi `500` hoặc timeout | Mất kết nối Database MongoDB | [Sự cố 1](#1-mất-kết-nối-database-container-note-api-db-bị-sập) |
| `note-api-app` và `note-api-db` đang `Up` | CloudWatch báo `CPU > 70%`, web/API phản hồi chậm | Máy chủ EC2 bị quá tải CPU / RAM | [Sự cố 2](#2-quá-tải-cpu-máy-chủ-cpu-alert) |
| `note-api-app` bị `Exited` / `Restarting`, `nginx` vẫn `active` | Truy cập web qua port 80 gặp lỗi `502 Bad Gateway` | Backend Node.js (`note-api-app`) bị sập hoặc không lắng nghe port `3000` | [Sự cố 3](#3-dịch-vụ-backend-note-api-app-bị-sập--lỗi-502-bad-gateway) |
| Container không khởi động được hoặc DB lỗi ghi dữ liệu | `df -h` báo phân vùng `/` đạt `95%–100%` | Ổ cứng EC2 bị đầy (Docker cache, log, backup) | [Sự cố 4](#4-đầy-ổ-cứng-máy-chủ-ec2-no-space-left-on-device) |
| Code mới chưa cập nhật trên EC2 sau khi `git push` | GitHub Actions báo job `deploy` thất bại (Failed) | Lỗi quá trình Deploy CI/CD qua SSH / Docker Compose | [Sự cố 5](#5-lỗi-triển-khai-tự-động-cicd-pipeline-deploy-thất-bại) |

---

## 2. Danh mục sự cố thường gặp

| # | Tên sự cố | Nguồn phát hiện / Ghi chú |
|---|---|---|
| 1 | [Mất kết nối Database (Container `note-api-db` bị sập)](#1-mất-kết-nối-database-container-note-api-db-bị-sập) | Production (AWS EC2) / API `/notes` trả về `500`, `docker ps` |
| 2 | [Quá tải CPU máy chủ (CPU Alert)](#2-quá-tải-cpu-máy-chủ-cpu-alert) | Production (AWS EC2) / Cảnh báo AWS CloudWatch `CPU > 70%` |
| 3 | [Dịch vụ Backend `note-api-app` bị sập / Lỗi 502 Bad Gateway](#3-dịch-vụ-backend-note-api-app-bị-sập--lỗi-502-bad-gateway) | Production (AWS EC2) / Trình duyệt & Nginx `error.log` |
| 4 | [Đầy ổ cứng máy chủ EC2 (`No space left on device`)](#4-đầy-ổ-cứng-máy-chủ-ec2-no-space-left-on-device) | Production (AWS EC2) / `docker compose up`, MongoDB hoặc `scripts/backup.sh` |
| 5 | [Lỗi triển khai tự động CI/CD (Pipeline Deploy thất bại)](#5-lỗi-triển-khai-tự-động-cicd-pipeline-deploy-thất-bại) | GitHub Actions (`.github/workflows/deploy.yml`) / Sau khi push nhánh `main` |

---

### Chi tiết xử lý sự cố

#### 1. Mất kết nối Database (Container `note-api-db` bị sập)

##### Triệu chứng (Symptoms)

- **Giao diện/Client:** Người dùng vào web thấy trang quay vòng vòng (loading mãi) hoặc không tải/lưu được ghi chú; các API `/notes` trả về lỗi HTTP `500`.
- **Giám sát (Monitoring):** Lệnh `docker ps` không thấy container `note-api-db` ở trạng thái `Up` (hoặc hiển thị `Restarting` / `Exited`); `GET /health` vẫn có thể trả về `200 OK` nhưng truy vấn DB thất bại.

##### Xác minh (Verification)

Các lệnh để chắc chắn hệ thống đang mắc đúng lỗi này (tránh đoán mò):

```bash
# Kiểm tra trạng thái container MongoDB và log lỗi
docker ps -a --filter "name=note-api-db"
docker logs --tail 100 note-api-db

# Kiểm tra log kết nối MongoDB từ phía ứng dụng Node.js
docker logs --tail 50 note-api-app
```

##### Nguyên nhân thường gặp (Root Causes)

- Container `note-api-db` bị hệ điều hành tắt đột ngột do hết RAM (OOM Killer) hoặc crash tiến trình `mongod`.
- Tệp dữ liệu hoặc lock file trong volume `mongo_data` bị hỏng sau khi máy chủ tắt nguồn đột ngột.
- Sai cấu hình biến môi trường `MONGO_URI` hoặc mất kết nối mạng Docker `note-network` giữa `note-api-app` và `note-api-db`.

##### Khắc phục (Resolution)

Các bước cụ thể để đưa hệ thống hoạt động trở lại:

```bash
# 1. Khởi động lại service database
docker compose restart db

# 2. Nếu container vẫn lỗi hoặc dữ liệu bị hỏng, kiểm tra danh sách backup và khôi phục từ bản sao lưu gần nhất
ls -lt /home/ubuntu/backups
./scripts/restore.sh /home/ubuntu/backups/<ten_thu_muc_backup>

# 3. Khởi động lại cả stack để đảm bảo app kết nối lại ổn định
docker compose up -d
```

**Cách kiểm tra sau khi khắc phục:** Chạy `docker ps` thấy `note-api-db` ở trạng thái `Up`, đồng thời chạy `curl -i http://localhost:3000/notes` nhận được mã `200 OK` cùng danh sách ghi chú JSON.

##### Phòng tránh (Prevention)

- Giữ cấu hình `restart: always` trong `docker-compose.yml` để Docker tự động khởi động lại container `note-api-db` khi gặp sự cố.
- Thiết lập cronjob chạy định kỳ `./scripts/backup.sh` hằng ngày để luôn có bản sao lưu mới trong `/home/ubuntu/backups`.
- Thêm healthcheck cho dịch vụ `db` trong `docker-compose.yml` và cấu hình cảnh báo khi container dừng hoặc `GET /notes` trả về lỗi `5xx`.

---

#### 2. Quá tải CPU máy chủ (CPU Alert)

##### Triệu chứng (Symptoms)

- **Giao diện/Client:** Trang web và các thao tác tạo/xóa ghi chú phản hồi rất chậm hoặc bị timeout.
- **Giám sát (Monitoring):** Nhận email cảnh báo từ AWS CloudWatch: `CPU utilization > 70%`.

##### Xác minh (Verification)

Các lệnh để chắc chắn hệ thống đang mắc đúng lỗi này (tránh đoán mò):

```bash
# SSH vào EC2, kiểm tra tiến trình và container nào đang tiêu tốn nhiều CPU/RAM
htop
docker stats --no-stream

# Theo dõi log của ứng dụng theo thời gian thực để tìm request bất thường hoặc vòng lặp lỗi
docker logs -f --tail 100 note-api-app
```

##### Nguyên nhân thường gặp (Root Causes)

- Ứng dụng Node.js gặp rò rỉ bộ nhớ (memory leak), vòng lặp vô hạn hoặc xử lý lượng request tăng đột biến.
- Truy vấn MongoDB chậm (chưa đánh index hoặc dữ liệu lớn) khiến CPU tăng cao kéo dài.
- Quá trình `docker compose up -d --build` hoặc tác vụ nền (như backup/nén dữ liệu) chạy cùng lúc trên instance EC2 cấu hình nhỏ (ví dụ `t2.micro` / `t3.micro`).

##### Khắc phục (Resolution)

Các bước cụ thể để đưa hệ thống hoạt động trở lại:

```bash
# Tạm thời: khởi động lại service web để giải phóng tài nguyên bị treo
docker compose restart app

# Nếu vẫn quá tải do truy vấn hoặc cả stack bị nghẽn, khởi động lại toàn bộ
docker compose restart
```

**Cách kiểm tra sau khi khắc phục:** Chạy `docker stats --no-stream` thấy `%CPU` của `note-api-app` và `note-api-db` giảm xuống mức bình thường, biểu đồ CloudWatch hạ dưới ngưỡng `70%`, và `curl -w "\nTime: %{time_total}s\n" http://localhost:3000/health` phản hồi nhanh.

##### Phòng tránh (Prevention)

- Cấu hình giới hạn tài nguyên (`mem_limit`, `cpus`) cho từng container trong `docker-compose.yml` để tránh một dịch vụ chiếm toàn bộ CPU của máy chủ.
- Đặt cảnh báo sớm trên CloudWatch ở ngưỡng cảnh báo phụ (ví dụ `CPU > 60%` trong 5 phút) và bật swap trên EC2 để giảm nguy cơ treo máy.
- Rà soát code Node.js định kỳ (tối ưu query MongoDB, tránh memory leak) và cân nhắc nâng cấp loại instance EC2 khi lưu lượng truy cập tăng.

---

#### 3. Dịch vụ Backend `note-api-app` bị sập / Lỗi 502 Bad Gateway

##### Triệu chứng (Symptoms)

- **Giao diện/Client:** Người dùng truy cập IP Public của EC2 thấy màn hình lỗi **`502 Bad Gateway`** từ Nginx hoặc không thể kết nối tới API.
- **Giám sát (Monitoring):** Lệnh `curl http://localhost/health` trả về `502 Bad Gateway`, `curl http://localhost:3000/health` báo `Connection refused`.

##### Xác minh (Verification)

Các lệnh để chắc chắn hệ thống đang mắc đúng lỗi này (tránh đoán mò):

```bash
# Kiểm tra trạng thái container note-api-app và mã thoát (Exit Code)
docker ps -a --filter "name=note-api-app"

# Xem log crash của ứng dụng Node.js
docker logs --tail 100 note-api-app

# Kiểm tra log lỗi của Nginx Reverse Proxy
sudo tail -n 50 /var/log/nginx/error.log
```

##### Nguyên nhân thường gặp (Root Causes)

- Code mới được deploy có lỗi cú pháp (syntax error), thiếu dependency trong `package.json`, hoặc lỗi runtime chưa được bắt (`UnhandledPromiseRejection` / `UncaughtException`).
- Xung đột cổng `3000` trên máy chủ (ví dụ tiến trình PM2 cũ chạy `server.js` vẫn đang chiếm port `3000` khiến container `note-api-app` không bind được port).
- Biến môi trường hoặc file cấu hình `Dockerfile` / `docker-compose.yml` bị sai lệch.

##### Khắc phục (Resolution)

Các bước cụ thể để đưa hệ thống hoạt động trở lại:

```bash
# 1. Nếu bị xung đột port 3000 do tiến trình PM2 cũ, kiểm tra và dừng tiến trình chiếm port
sudo ss -tulpn | grep :3000
pm2 stop note-api || true

# 2. Build lại và khởi động container ứng dụng
docker compose up -d --build app

# 3. Kiểm tra lại trạng thái Nginx
sudo nginx -t && sudo systemctl reload nginx
```

**Cách kiểm tra sau khi khắc phục:** Chạy `curl -i http://localhost/health` trả về `HTTP/1.1 200 OK` với nội dung `{"status":"OK",...}` và truy cập trình duyệt không còn lỗi `502`.

##### Phòng tránh (Prevention)

- Duy trì `restart: always` trong `docker-compose.yml` và đảm bảo các tiến trình thủ công (PM2) đã được tắt hoàn toàn khi chuyển sang Docker.
- Không bỏ qua bước kiểm thử tự động (`npm test`) trong GitHub Actions trước khi deploy.
- Thêm bước kiểm tra `curl -f http://localhost:3000/health` ngay cuối quy trình deploy để phát hiện sớm container không lên.

---

#### 4. Đầy ổ cứng máy chủ EC2 (`No space left on device`)

##### Triệu chứng (Symptoms)

- **Giao diện/Client:** Không thể tạo ghi chú mới (`POST /notes` trả về lỗi `500`), hoặc ứng dụng bị ngừng đột ngột sau một đợt deploy mới.
- **Giám sát (Monitoring):** Log Docker/MongoDB hoặc GitHub Actions xuất hiện thông báo **`no space left on device`**; `scripts/backup.sh` chạy thất bại.

##### Xác minh (Verification)

Các lệnh để chắc chắn hệ thống đang mắc đúng lỗi này (tránh đoán mò):

```bash
# Kiểm tra dung lượng ổ đĩa tổng thể và inodes
df -h
df -i

# Kiểm tra dung lượng chiếm dụng bởi Docker (images, containers, build cache) và thư mục backup
docker system df
du -sh /home/ubuntu/backups/* /var/lib/docker/* 2>/dev/null | sort -h
```

##### Nguyên nhân thường gặp (Root Causes)

- Lệnh `sudo docker compose up -d --build` chạy lặp lại nhiều lần trong mỗi lần CI/CD deploy tạo ra nhiều dangling Docker images và build cache không được dọn dẹp.
- Các bản sao lưu database trong `/home/ubuntu/backups` tích tụ lâu ngày không có chính sách xóa bản cũ.
- Log của container Docker hoặc Nginx tăng kích thước quá lớn do lỗi lặp lại liên tục.

##### Khắc phục (Resolution)

Các bước cụ thể để đưa hệ thống hoạt động trở lại:

```bash
# 1. Dọn dẹp Docker images cũ, container đã dừng và build cache (KHÔNG dùng --volumes để giữ nguyên mongo_data)
docker system prune -af

# 2. Xóa các thư mục backup quá cũ nếu cần giải phóng thêm dung lượng (giữ lại các bản gần nhất)
ls -lt /home/ubuntu/backups
# rm -rf /home/ubuntu/backups/db_backup_<ngay_cu>

# 3. Khởi động lại dịch vụ để đảm bảo hệ thống phục hồi hoàn toàn
docker compose up -d
```

**Cách kiểm tra sau khi khắc phục:** Chạy `df -h` xác nhận dung lượng trống của phân vùng `/` đã an toàn (dưới `80%`), chạy `docker ps` thấy các container hoạt động ổn định và thử tạo ghi chú mới qua `POST /notes` thành công.

##### Phòng tránh (Prevention)

- Cấu hình giới hạn kích thước log trong `docker-compose.yml` (`logging: driver: "json-file", options: max-size: "10m", max-file: "3"`).
- Bổ sung bước dọn dẹp `sudo docker image prune -f` sau mỗi lần deploy thành công hoặc thiết lập cronjob dọn cache và xoay vòng (rotation) thư mục `/home/ubuntu/backups` (ví dụ chỉ giữ lại backup trong 7–14 ngày).
- Thiết lập cảnh báo CloudWatch khi dung lượng ổ đĩa sử dụng vượt quá `80%`.

---

#### 5. Lỗi triển khai tự động CI/CD (Pipeline Deploy thất bại)

##### Triệu chứng (Symptoms)

- **Giao diện/Client:** Đã `git push` code mới lên nhánh `main` nhưng giao diện hoặc API trên server vẫn chạy phiên bản cũ (hoặc dịch vụ bị gián đoạn giữa chừng khi đang `docker compose down`).
- **Giám sát (Monitoring):** Trang GitHub Actions của repository báo job **`deploy` Failed** (đánh dấu X đỏ) trong workflow `.github/workflows/deploy.yml`.

##### Xác minh (Verification)

Các lệnh để chắc chắn hệ thống đang mắc đúng lỗi này (tránh đoán mò):

```bash
# Kiểm tra commit hiện tại trên máy chủ EC2 so với GitHub
git log -n 3 --oneline
git status

# Kiểm tra dịch vụ SSH, UFW và trạng thái container trên EC2
sudo systemctl status ssh --no-pager
sudo ufw status
docker compose ps
```

##### Nguyên nhân thường gặp (Root Causes)

- Sai hoặc hết hạn GitHub Secrets (`SERVER_HOST` thay đổi do EC2 khởi động lại không dùng Elastic IP, sai `SERVER_USER`, hoặc sai `SERVER_SSH_KEY`).
- AWS Security Group hoặc UFW trên EC2 chặn kết nối SSH (port `22`) từ runner của GitHub Actions.
- Lệnh `sudo docker compose up -d --build` trên EC2 gặp lỗi mạng khi pull base image, lỗi cú pháp Dockerfile, hoặc thiếu quyền thực thi / đầy ổ cứng.

##### Khắc phục (Resolution)

Các bước cụ thể để đưa hệ thống hoạt động trở lại:

```bash
# 1. Nếu lỗi do sai IP/SSH Secret: kiểm tra IP Public mới của EC2 và cập nhật lại SERVER_HOST trong GitHub Repository Secrets

# 2. Đồng bộ code thủ công và khởi chạy lại container trên EC2 để khôi phục ngay dịch vụ
git fetch --all
git reset --hard origin/main
chmod +x scripts/backup.sh scripts/restore.sh
sudo docker compose down
sudo docker compose up -d --build
```

**Cách kiểm tra sau khi khắc phục:** Chạy `git log -n 1 --oneline` khớp với commit mới nhất trên nhánh `main`, `curl -i http://localhost/health` trả về `200 OK`, và chạy lại (**Re-run failed jobs**) trên GitHub Actions thành công (màu xanh).

##### Phòng tránh (Prevention)

- Gắn **Elastic IP** cho máy chủ AWS EC2 để địa chỉ `SERVER_HOST` không bị thay đổi mỗi lần stop/start instance.
- Mở port `22` đúng cấu hình trong Security Group / UFW và kiểm tra kỹ bộ Secrets (`SERVER_HOST`, `SERVER_USER`, `SERVER_SSH_KEY`) khi thay đổi hạ tầng.
- Luôn chạy kiểm thử `npm test` ở local và chờ job `test` trên GitHub Actions pass trước khi merge vào nhánh `main`.
