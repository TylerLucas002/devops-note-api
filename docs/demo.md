# Live demo và Q&A — không bao gồm quay video

## Chuẩn bị

- Mở Actions, website, `/health`, terminal EC2 và CloudWatch nếu đã cấu hình.
- Ghi SHA đang chạy; chuẩn bị một thay đổi giao diện nhỏ và kết quả kỳ vọng.
- Kiểm tra backup gần nhất và môi trường thử nghiệm riêng. Không dùng production để demo xóa dữ liệu hoặc làm sập dịch vụ.
- Có log/ảnh dự phòng: [Week 4](../evidence/week-4/README.md). Không giả lập kết quả thành công.

## Kịch bản

1. 3 phút: trình bày sơ đồ browser → Nginx → app → DB/volume, phân công theo README.
2. 5–7 phút: commit thay đổi giao diện → CI test/operations → deploy → tải lại web → đối chiếu `version` trong `/health` với SHA trên Actions. Lưu ý build/tests có thể mất lâu hơn; chuẩn bị run thành công trước đó.
3. 3–5 phút: xem JSON logs, health status, CloudWatch thực nếu đã bật; trình bày backup/restore từ log thực nghiệm, checksum và bản ghi đã phục hồi.
4. 5–10 phút: chọn sự cố ở môi trường riêng, nêu giả thuyết, chạy lệnh xác minh, sửa, smoke test; trả lời Q&A.

## Câu hỏi cần trả lời được

- Tại sao volume giữ được dữ liệu khi tạo lại container? Lệnh nào xóa volume?
- `/live` khác `/health` thế nào? DB chết thì trả HTTP gì?
- Vì sao test thất bại chặn deploy? Làm sao biết server chạy đúng commit?
- Vì sao build trước khi thay app? Vì sao vẫn có downtime?
- Restart khác recreate container khi sửa biến môi trường thế nào?
- Backup thành công có đủ chưa? Checksum và đọc lại bản ghi chứng minh điều gì?
- Rollback image có rollback dữ liệu không?
- Cổng nào public, cổng nào nội bộ? Hiện có TLS/auth chưa?
- CPU metric có sẵn nhưng RAM/disk cần gì? Alarm đã gửi thông báo thật chưa?

## Checklist đóng gói

- Xác nhận các mục AWS còn thiếu trong evidence, không tự đánh dấu đã hoàn thành.
- Giữ paper, sơ đồ, guide, playbook và link CI đúng phiên bản.
- Tạo tag/release sau khi deployment cuối được xác minh.
- Nhóm tự xác nhận phân công và tập trả lời câu hỏi; tài liệu không thay thế việc hiểu hệ thống.
