# Minh chứng Week 4

## Kết quả thực nghiệm độc lập — 11/11/2026

- Node.js 24.22.1 ở môi trường kiểm tra; image production/CI dùng Node 22.
- API tests: 10/10 pass. Cài bằng `npm ci --ignore-scripts`.
- Docker build và readiness: pass.
- Backup → xóa → restore: đúng ID và content.
- Checksum hỏng bị từ chối trước khi dừng app.
- App stopped, DB stopped, sai MONGO_URI: đều phát hiện và phục hồi.
- Audit dependency production sau cập nhật: không có lỗ hổng được báo tại thời điểm kiểm tra.

Log chi tiết xem artifact `operations-evidence` trên run Actions của phiên bản này. Script chạy lại:

```bash
mkdir -p work
docker build -t devops-note-api:review .
COMPOSE_PROJECT_NAME=note-check-manual bash scripts/verify-operations.sh 2>&1 | tee work/operations.log
```

Script chỉ chấp nhận tên project `note-check-*`, dùng container/volume riêng và dọn chúng sau khi chạy. Không chạy bằng tên project production. Log có thể chứa đường dẫn và định danh hạ tầng test; review trước khi chia sẻ công khai.

## Minh chứng chưa được xác nhận qua tài khoản AWS

- Cấu hình CloudWatch alarm/agent và việc nhận thông báo.
- Cron backup trên EC2 thực sự được cài và chạy theo lịch.
- Security Group/UFW/Nginx/TLS hiện tại trên host (các ảnh tuần 1 là lịch sử).
- Dựng đầy đủ Ubuntu sạch từ guide trên một EC2 khác.
- Live demo và mức độ hiểu của từng thành viên.

Các mục này cần người có quyền AWS/SSH xác minh; không gộp log CI thành minh chứng đã hoàn thành trên production. Video được bỏ khỏi phạm vi thực hiện theo yêu cầu người phụ trách.

## Log lưu trong repository

- [API: 10 tests pass](api-tests.txt)
- [Operations: backup/restore và 3 sự cố](operations-test.txt)
- [Audit dependency production](dependency-audit.txt)

Thử nghiệm rollout/rollback bổ sung bị giới hạn dung lượng ở môi trường Docker trong cloud (`no space left on device`). Do đó chưa coi automatic rollback là đã kiểm chứng thành công; cần diễn tập lại trên staging đủ dung lượng. Không có thao tác gây lỗi trên EC2 production. Bản code được chuẩn bị trên nhánh riêng để review; chưa xác minh deployment mới trên EC2. Kết nối GitHub chưa có quyền ghi repo gốc (HTTP 403); cập nhật trạng thái khi có run deploy thành công thật.
