# Troubleshooting playbook

Ba tình huống đầu có thực nghiệm tự động bằng `scripts/verify-operations.sh`, log ở [minh chứng](../evidence/week-4/README.md) và artifact Actions `operations-evidence`. Các thí nghiệm dùng project `note-check-*` riêng. Không chạy lệnh gây lỗi trên EC2 đang phục vụ.

## Triage

```bash
sudo docker compose ps -a
curl -i http://localhost/health
curl -i http://localhost:3000/live
sudo docker compose logs --tail 50 app db
sudo systemctl status nginx --no-pager
sudo nginx -t
df -h
```

`/live=200`, `/health=503`: tiến trình app còn sống nhưng DB chưa sẵn sàng. Nginx `502` và cổng 3000 không trả lời: kiểm tra app/port. App trực tiếp khỏe nhưng qua Nginx lỗi: kiểm tra proxy, SG, UFW.

## 1. Container app dừng — đã thực nghiệm

**Triệu chứng:** không kết nối được cổng app; khi đi qua Nginx thường nhận 502.

**Xác minh:** `docker compose ps -a app`, `docker compose logs --tail 30 app`, `curl -i http://localhost:3000/health`.

**Nguyên nhân thực nghiệm:** chủ động `docker compose stop app` trong project riêng. Không kết luận mọi 502 đều do nguyên nhân này; server thật có thể OOM, lỗi code hoặc trùng port.

**Khôi phục:** `sudo docker compose up -d --no-build --wait --wait-timeout 120 app`, sau đó `sudo bash scripts/smoke-test.sh http://localhost`. Test độc lập xác minh API/homepage phục hồi; proxy Nginx production phải kiểm tra riêng.

**Phòng tránh:** restart policy, test trước deploy, smoke test sau deploy; monitoring endpoint để phát hiện unhealthy. Lệnh stop có chủ đích không được restart policy tự đảo ngược.

## 2. Container DB dừng — đã thực nghiệm

**Triệu chứng:** `/health` trả 503; thao tác dữ liệu thất bại. `/live` vẫn có thể 200.

**Xác minh:** `docker compose ps -a db`, `docker compose logs --tail 50 db`, `curl -i http://localhost:3000/health`.

**Nguyên nhân thực nghiệm:** `docker compose stop db`. Script backup chạy lúc DB dừng trả mã lỗi, không báo thành công.

**Khôi phục:** `sudo docker compose up -d --no-build --wait --wait-timeout 120`; chạy smoke test, đọc dữ liệu cũ. Nếu có OOM/disk full, sửa tài nguyên trước. Không xóa volume để “sửa nhanh”.

**Phòng tránh:** healthcheck DB, giám sát tài nguyên, backup có kiểm tra, giới hạn log. Restore chỉ dùng khi xác nhận mất/hỏng dữ liệu; không restore chỉ vì container dừng.

## 3. Sai MONGO_URI — đã thực nghiệm

**Triệu chứng:** app không healthy, có thể restart liên tục; log `database_connection_failed`.

**Xác minh:** kiểm tra cấu hình URI ở nơi lưu bí mật mà không chụp/in mật khẩu; service DB tên `db`, port nội bộ 27017, DB `notedb`. Kiểm tra trạng thái và DNS/network Compose.

**Nguyên nhân thực nghiệm:** đặt URI tới hostname không tồn tại `missing-db`. `docker compose up --wait` trả lỗi khi app không sẵn sàng.

**Khôi phục:** sửa `.env` về `MONGO_URI=mongodb://db:27017/notedb`, dùng `sudo docker compose up -d --no-build --wait --wait-timeout 120 app`. `restart` đơn thuần không áp dụng biến môi trường mới. Smoke test xác nhận DB up và đúng version.

**Phòng tránh:** config mẫu, kiểm tra readiness thật, giữ secret ngoài repo. Thay đổi URI/major DB cần review riêng; rollback image không tự sửa cấu hình DB sai.

## 4. Backup hỏng — đã thực nghiệm

**Triệu chứng:** checksum mismatch khi restore, script trả lỗi.

**Xác minh:** kiểm tra file archive và `.sha256`; `sha256sum -c FILE.sha256` trong thư mục backup. Test đã thêm byte vào archive và xác nhận restore bị chặn trước khi dừng app.

**Nguyên nhân thực nghiệm:** archive bị thay đổi sau backup. Thực tế có thể copy thiếu file, disk error hoặc chọn sai checksum.

**Khôi phục:** giữ lại bản lỗi để điều tra, chọn bản backup khác đã xác minh. Không tạo lại checksum cho dữ liệu hỏng rồi restore. Diễn tập khôi phục trên staging trước production.

**Phòng tránh:** checksum, backup ngoài instance, định kỳ kiểm tra restore và theo dõi exit code/cron log.

## 5. Quá tải CPU hoặc đầy disk — hướng dẫn, chưa thực nghiệm trong phiên này

**Triệu chứng:** response chậm, CloudWatch CPU cao, `no space left on device`.

**Xác minh:** `docker stats --no-stream`, `free -m`, `df -h`, `df -i`, `docker system df`, log OOM. CloudWatch RAM/disk chỉ có nếu đã cài agent.

**Nguyên nhân:** xác định từ tiến trình và tài nguyên thật; có thể build, query nặng, log hoặc backup tích tụ. Không tự kết luận memory leak từ CPU cao.

**Khôi phục:** dừng tác vụ gây tải đã xác định; dọn từng tài nguyên không dùng sau kiểm tra. Giữ image rollback và backup tốt; không chạy `prune -a` hàng loạt khi đang cần khôi phục. Nếu disk hỏng/hết dài hạn, lập kế hoạch mở rộng volume.

**Phòng tránh:** log rotation, theo dõi disk/backup, cảnh báo CPU, đo tài nguyên trước khi chọn instance.

## 6. Deploy thất bại — quy trình điều tra

**Triệu chứng:** Actions đỏ, version HTTP không đổi hoặc app không healthy.

**Xác minh:** đọc job test/operations/deploy để xác định lớp lỗi. SSH timeout: kiểm tra instance/IP/SG/key. Build fail: app cũ phải còn chạy. Health fail: xem log app/DB và kết quả rollback.

**Khôi phục:** sửa đúng nguyên nhân; nếu app cũ đã được rollback healthy thì giữ phiên bản đó và sửa trên branch trước. Dùng SHA đầy đủ của bản đã kiểm chứng khi deploy lại. Không rerun mù khi thiếu disk hoặc sai cấu hình.

**Phòng tránh:** build trước thay container, `needs` cả test và operations, serialize deploy, deploy đúng SHA, kiểm tra version. Không tuyên bố rollback schema/DB đã được tự động hóa.
