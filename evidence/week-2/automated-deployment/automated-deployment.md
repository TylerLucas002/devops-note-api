## Ảnh minh chứng triển khai CI/CD và Persistence

### Hình 1 – Trạng thái ban đầu (Before)

Ứng dụng **Smart Note** được triển khai trên máy chủ AWS EC2 với giao diện nền trắng cơ bản và tiêu đề `📝 Smart Note - DevOps Week 1`. Hệ thống đã lưu trữ sẵn một bản ghi nhớ trong cơ sở dữ liệu để phục vụ việc kiểm tra khả năng duy trì dữ liệu sau khi triển khai phiên bản mới.

### Hình 2 – CI/CD Pipeline hoạt động tự động (Automation)

Thay vì SSH vào máy chủ để cập nhật mã nguồn thủ công, thành viên nhóm **BaoHuy903** chỉ cần thực hiện lệnh `git push` để đẩy commit có tên `fix ui` lên nhánh `main` của kho lưu trữ GitHub.

GitHub Actions tự động phát hiện sự kiện push và kích hoạt quy trình CI/CD. Pipeline hoàn thành thành công trong **1 phút 16 giây**, với cả hai tiến trình:

- **Test:** Thực hiện kiểm thử và hoàn thành thành công.
- **Deploy:** Tự động triển khai phiên bản mã nguồn mới lên máy chủ AWS EC2.

Kết quả này cho thấy quy trình kiểm thử và triển khai đã được tự động hóa, giảm nhu cầu thao tác trực tiếp trên máy chủ.

### Hình 3 – Trạng thái sau cập nhật (After)

Sau khi GitHub Actions thông báo triển khai thành công, người dùng chỉ cần tải lại trang web để thấy giao diện mới ở chế độ **Dark Mode**, với tiêu đề `DevOps Smart Note - Docker • MongoDB • CI/CD Automated Platform`.

Đặc biệt, bản ghi nhớ đã tồn tại từ trước vẫn được hiển thị đầy đủ trên giao diện mới. Điều này chứng minh rằng:

- **CI/CD Automation:** Phiên bản ứng dụng mới được triển khai tự động thành công lên AWS EC2.
- **Data Persistence:** Dữ liệu trong MongoDB vẫn được giữ nguyên sau khi Container được khởi tạo lại, không bị mất khi cập nhật ứng dụng.

**Kết luận:** Kết quả thực nghiệm xác nhận quy trình CI/CD hoạt động thành công và dữ liệu ứng dụng được duy trì qua quá trình triển khai phiên bản mới.
