# Monitoring, security và vận hành

## Kiểm tra trực tiếp

```bash
sudo docker compose ps
curl -i http://localhost/health
sudo docker compose logs --since 10m app
sudo docker stats --no-stream
sudo tail -n 50 /var/log/nginx/error.log
df -h
```

Log app là JSON gồm method, path, HTTP status, durationMs, version; không log body, URI DB hay credentials. Docker giới hạn 10 MB/file, 3 file/container. Các endpoint trả 503 khi DB chưa sẵn sàng. Không xem `/live` là chứng minh đọc/ghi DB thành công.

## CloudWatch (cần thực hiện trong tài khoản AWS)

Đã có hướng dẫn triển khai, chưa có xác nhận truy cập tài khoản AWS trong phiên hoàn thiện repo. Chỉ đánh dấu xong khi thấy alarm/metric thật; không dùng phần hướng dẫn này làm minh chứng đã bật alarm.

1. EC2 console vùng `ap-southeast-2`: chọn đúng instance, ghi Instance ID, đối chiếu IP với `SERVER_HOST`.
2. CloudWatch → Alarms → Create alarm → EC2 → Per-Instance Metrics → `CPUUtilization` của instance đó.
3. Statistic Average, period 5 phút, threshold >70%, 2/2 datapoints; missing data dùng `missing` để trạng thái thiếu dữ liệu hiển thị rõ.
4. Gắn SNS topic đã được nhóm phê duyệt, xác nhận subscription và kiểm tra nhận cảnh báo. Nếu chưa cấu hình nơi nhận thì alarm chưa tạo được thông báo tới thành viên.
5. Lưu ảnh metric, alarm, trạng thái và recovery, che email/định danh không cần thiết. Chỉ thử CPU tải cao trên staging; có thể dùng `SetAlarmState` để kiểm tra luồng thông báo, nhưng cần ghi rõ đó là trạng thái giả lập chứ không phải CPU thực vượt ngưỡng.

EC2 mặc định có CPU/network/status checks; RAM/disk cần CloudWatch Agent và IAM role phù hợp. Chưa có agent thì không được nói đã giám sát RAM/disk trên CloudWatch. Kiểm tra `df`, `free` thủ công trong demo. Theo dõi endpoint từ bên ngoài (ví dụ CloudWatch Synthetics) là bước bổ sung có chi phí, cần cấu hình riêng.

## Security và giới hạn

- App chưa có auth; người truy cập đều có thể tạo/xóa ghi chú dùng chung. Chỉ dùng dữ liệu demo, chưa phù hợp lưu ghi chú cá nhân.
- Cấu hình Compose giữ DB trong mạng nội bộ, app chỉ host loopback, không mount Docker socket vào app.
- Validation giới hạn title/content/body; UI escape category như title/content để tránh HTML injection.
- Secrets GitHub được dùng ở job deploy; tuyệt đối không in SSH private key hoặc `.env` vào log/minh chứng.
- HTTP hiện tại chưa đảm bảo bảo mật trên đường truyền. Cần domain và chứng chỉ để triển khai TLS; không tuyên bố đã có HTTPS chỉ vì SG mở 443.
- MongoDB 6.0 được giữ để tương thích dữ liệu hiện hữu, đã hết vòng đời hỗ trợ. Trước sử dụng production thực, lập kế hoạch nâng cấp theo từng major với backup/FCV đúng quy trình; không đổi image DB trực tiếp sang major mới.
- Node base image và Actions dùng version tags; có thể pin digest/commit để cố định supply chain khi vận hành dài hạn.

## Backup/restore

Xem [deployment guide](../deployment.md#6-backup-và-cron). Backup lỗi trả exit code khác 0, không in thành công. Restore yêu cầu checksum, dừng writers và có xác nhận mục tiêu. Lịch chạy chỉ được coi đã bật sau khi cài cron trên server và thấy log/backup mới. RPO mục tiêu 24 giờ nếu cron thành công mỗi ngày; chưa phải SLA đã đo. Đo RTO bằng thời gian từ dừng đến smoke test phục hồi trong lần diễn tập cụ thể.

## Phân công xác minh

Theo phân công ban đầu: Toàn phụ trách EC2/Nginx/UFW; Minh API/test; Huy MongoDB/backup và hỗ trợ CI/CD. Nhóm cần xác nhận lại người thực hiện các thay đổi mới; lịch sử commit không chứng minh từng người đã tự thao tác hay hiểu toàn bộ nội dung.
