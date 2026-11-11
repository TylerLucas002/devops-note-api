# Smart Note — DevOps Final Project 2026

Nhóm **Làng Xì Mi**: Nguyễn Bá Toàn, Trần Tiến Minh, Hồ Thăng Bảo Huy.

Ứng dụng ghi chú dùng Express, MongoDB và Docker Compose trên Ubuntu EC2. Nginx trên host nhận HTTP, proxy tới app chỉ bind `127.0.0.1:3000`. MongoDB không publish cổng ra host. Đây là ứng dụng demo dùng chung, chưa có tài khoản hay phân quyền; chỉ dùng dữ liệu thực nghiệm.

## Bắt đầu

Cài Docker Engine + Compose v2. Chạy trong thư mục clone có tên `devops-note-api`:

```bash
git clone https://github.com/batoannguyen52-debug/devops-note-api.git
cd devops-note-api
cp .env.example .env
docker compose up -d --build --wait
bash scripts/smoke-test.sh
```

Mở `http://localhost:3000` trên máy chạy Docker. Hướng dẫn Ubuntu sạch, Nginx, firewall và CI/CD: [deployment](docs/deployment.md).

## API và kiểm thử

| Route | Kết quả |
|---|---|
| `GET /` | Giao diện ghi chú |
| `GET /live` | Tiến trình HTTP đang chạy |
| `GET /health` | `200` khi ping MongoDB thành công; `503` khi chưa sẵn sàng; có version commit |
| `GET /notes` | Danh sách ghi chú |
| `POST /notes` | Tạo ghi chú: title, content, category tùy chọn |
| `DELETE /notes/:id` | Xóa; `400` nếu ID sai, `404` nếu không tồn tại |

Node.js 22.21+:

```bash
npm ci --ignore-scripts
npm test
```

Test dùng MongoDB tạm nếu không đặt `MONGO_URI`. CI dùng MongoDB 6.0. **Không trỏ test vào production** vì test có ghi/xóa dữ liệu.

## CI/CD

Push/PR chạy kiểm thử API và bộ kiểm thử vận hành Docker và rollback độc lập. Chỉ `main` được deploy, sau khi cả ba job test, operations và rollback đạt. Deploy checkout đúng commit, build trước khi thay app, backup DB, chờ healthcheck, xác minh version và API. Nếu lỗi sau khi thay container, script thử khôi phục image trước đó và giữ job ở trạng thái failed. Một instance vẫn có gián đoạn ngắn lúc thay app; không cam kết zero downtime.

Secrets: `SERVER_HOST`, `SERVER_USER`, `SERVER_SSH_KEY`. SSH user cần quyền `sudo` chạy Docker không hỏi mật khẩu. Các quyền này tương đương quyền quản trị server; giới hạn người có quyền sửa workflow/secrets.

## Hồ sơ và vận hành

- [Kiến trúc cuối](docs/architecture/README.md)
- [Dựng server sạch và rollback](docs/deployment.md)
- [Monitoring, security và backup](docs/operations/README.md)
- [Playbook thực nghiệm](docs/playbook.md)
- [Báo cáo kỹ thuật](docs/technical-report.md) và [bản Word](docs/technical-report.docx)
- [Kịch bản live demo và Q&A](docs/demo.md)
- [Minh chứng Week 4](evidence/week-4/README.md)
- [Tuần 1](evidence/week-1/README.md)
- [Deploy tuần 2](evidence/week-2/automated-deployment/automated-deployment.md), [persistence](evidence/week-2/database-persistence/database-persistence.md), [fail pipeline](evidence/week-2/fail-pipeline/fail-pipeline.md)

Không dùng `docker compose down -v` trên production. Không đổi tên thư mục/project Compose của server hiện hữu vì sẽ chọn volume khác. Không đưa `.env`, SSH key hoặc dữ liệu backup vào Git.
