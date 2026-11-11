
# Smart Note Web App

## System Architecture

Hệ thống **Smart Note Web App** vận hành theo mô hình **Client–Server** truyền thống, kết hợp **Reverse Proxy** và **Database cục bộ**, với quy trình hoạt động như sau:

### 1. Client (Trình duyệt người dùng)

- Người dùng truy cập vào địa chỉ **Public IP của AWS EC2**.
- Người dùng nhập tiêu đề và nội dung ghi chú, sau đó nhấn nút **"Lưu Ghi Chú"**.
- Trình duyệt đóng gói dữ liệu thành HTTP Request và gửi yêu cầu thông qua mạng Internet đến máy chủ.

### 2. Network & Firewall (AWS Security Group & UFW)

- Các yêu cầu truy cập đi qua lớp tường lửa **AWS Security Group** và **UFW**.
- Các cổng giao tiếp được cấu hình để phục vụ những mục đích sau:
  - **Port 80/443:** Truy cập Web qua HTTP/HTTPS.
  - **Port 22:** Quản trị máy chủ thông qua SSH.

### 3. Reverse Proxy (Nginx)

- **Nginx** đóng vai trò là Reverse Proxy, tiếp nhận lưu lượng truy cập từ bên ngoài.
- Nginx sử dụng cấu hình `proxy_pass` để chuyển tiếp các yêu cầu đến ứng dụng Backend bên trong hệ thống.

### 4. Application Runtime (Node.js & PM2)

- Ứng dụng Backend được xây dựng bằng **Node.js / Express** và lắng nghe các yêu cầu tại **Port 3000**.
- Backend tiếp nhận HTTP Request và xử lý logic nghiệp vụ của ứng dụng.
- **PM2** quản lý, giám sát và duy trì hoạt động của tiến trình ứng dụng.

### 5. Database (MongoDB)

- Node.js kết nối trực tiếp với cơ sở dữ liệu MongoDB cục bộ có tên `notedb`.
- Database thực hiện các thao tác dữ liệu cần thiết, bao gồm:
  - Ghi bản ghi ghi chú mới.
  - Đọc danh sách ghi chú để trả về cho người dùng.

---

## Request Flow

Quy trình xử lý một yêu cầu từ người dùng:

1. Người dùng thao tác trên trình duyệt và gửi HTTP Request.
2. Yêu cầu đi qua các lớp tường lửa AWS Security Group và UFW.
3. Nginx tiếp nhận yêu cầu và chuyển tiếp đến Backend thông qua `proxy_pass`.
4. Ứng dụng Node.js / Express xử lý yêu cầu tại Port 3000.
5. Backend tương tác với MongoDB (`notedb`) để đọc hoặc ghi dữ liệu.
6. Kết quả được Backend trả về qua Nginx đến trình duyệt người dùng.
