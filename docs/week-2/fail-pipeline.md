
### Minh chứng cơ chế chặn lỗi tự động (Fail Pipeline)

#### 1. Mục đích kiểm thử

Xác minh khả năng kiểm soát chất lượng mã nguồn của quy trình CI/CD, đảm bảo các thay đổi không vượt qua bước kiểm thử sẽ không được triển khai lên môi trường Production (AWS EC2).

#### 2. Kịch bản thực nghiệm

1. Chủ động sửa đổi một điều kiện kiểm thử trong bộ test, chẳng hạn thay đổi mã trạng thái API mong đợi hoặc làm sai lệch kết quả kỳ vọng của hàm kiểm thử.
2. Thực hiện lệnh `git push` để đẩy thay đổi lên nhánh `main` của repository trên GitHub.
3. Theo dõi quá trình thực thi của GitHub Actions để kiểm tra phản ứng của pipeline khi phát hiện lỗi.

#### 3. Kết quả ghi nhận

- **Job `test`:** GitHub Actions phát hiện lỗi khi kết quả thực tế không khớp với kết quả mong đợi và đánh dấu job ở trạng thái **Failure**.
- **Job `deploy`:** Không được thực thi do bước kiểm thử thất bại, ngăn pipeline tiếp tục quá trình triển khai phiên bản lỗi lên AWS EC2.
- **An toàn triển khai:** Quy trình dừng trước bước triển khai, hạn chế nguy cơ đưa mã nguồn không đạt yêu cầu kiểm thử vào môi trường Production.

#### 4. Ý nghĩa DevOps

Cơ chế Fail Pipeline giúp phát hiện lỗi sớm trong giai đoạn **CI (Continuous Integration)** và ngăn các thay đổi không vượt qua kiểm thử tiếp tục đi vào giai đoạn **CD (Continuous Delivery/Deployment)**. Qua đó, hệ thống giảm rủi ro triển khai lỗi và nâng cao độ tin cậy của quy trình phát hành phần mềm.

**Lưu ý:** Chỉ ghi nhận `deploy` ở trạng thái `Skipped` hoặc `Cancelled` theo trạng thái thực tế hiển thị trong GitHub Actions. Nếu chưa thực hiện thử nghiệm hoặc chưa có ảnh chụp kết quả, cần xác minh các trạng thái này trước khi sử dụng làm minh chứng thực nghiệm.
