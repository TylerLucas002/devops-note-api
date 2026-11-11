# Giải thích chi tiết các minh chứng cấu hình (Server Configuration Evidence)

Dưới đây là phần giải thích chi tiết cho các hình ảnh minh chứng kỹ thuật của Tuần 1:

## 1. Minh chứng Firewall & Network (`report1.png`)
* **Nội dung hiển thị:** Lệnh `sudo ufw status verbose` cho thấy tường lửa UFW đang ở trạng thái `active` (hoạt động).
* **Ý nghĩa & Giải thích:** 
  * Cấu hình bảo mật cơ bản cho máy chủ AWS EC2 đã được thiết lập chặt chẽ theo đúng yêu cầu.
  * Các cổng mạng được cấp phép truy cập cụ thể gồm: **Port 22 (OpenSSH)** phục vụ cho việc quản trị server từ xa qua SSH, và **Port 80, 443 (Nginx Full)** phục vụ cho lưu lượng truy cập Web HTTP/HTTPS công khai từ người dùng bên ngoài.

## 2. Minh chứng Quản lý Tiến trình Ứng dụng (`report1.2.png`)
* **Nội dung hiển thị:** Lệnh `pm2 status` hiển thị tiến trình ứng dụng có tên `note-api` đang ở trạng thái `online` với PID, mức sử dụng CPU (0%) và RAM ổn định.
* **Ý nghĩa & Giải thích:** 
  * Ứng dụng Backend Node.js đã được triển khai thành công và chạy ổn định trên môi trường production của server.
  * Công cụ **PM2** đóng vai trò giám sát tiến trình 24/7, tự động khởi động lại ứng dụng nếu xảy ra sự cố sập nguồn hay lỗi bất ngờ, đảm bảo tính sẵn sàng cao cho hệ thống.

## 3. Minh chứng Giao diện & Đọc/Ghi Dữ liệu (`report1.3.png`)
* **Nội dung hiển thị:** Giao diện trang web **Smart Note - DevOps Week 1** truy cập thông qua địa chỉ IP Public `3.25.171.188`.
* **Ý nghĩa & Giải thích:** 
  * Chứng minh ứng dụng đã hoàn toàn sẵn sàng và người dùng từ internet bên ngoài có thể truy cập thành công thông qua trình duyệt.
  * Phần hiển thị danh sách ghi chú thực tế trên giao diện xác thực rằng ứng dụng đã kết nối thành công với cơ sở dữ liệu MongoDB và thực hiện tốt thao tác đọc/ghi dữ liệu.
