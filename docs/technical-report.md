# Smart Note: Triển khai và vận hành ứng dụng ghi chú với Docker và CI/CD

**Môn học:** DevOps, học kỳ 2026. **Nhóm:** Làng Xì Mi.
**Thành viên:** Nguyễn Bá Toàn, Trần Tiến Minh, Hồ Thăng Bảo Huy.
**Phiên bản báo cáo:** hoàn thiện kỹ thuật ngày 11/11/2026. Báo cáo ghi rõ các kết quả đã đo và các cấu hình AWS chưa được xác minh. Phân trang 6–10 trang phụ thuộc mẫu trình bày của môn học; đây là bản nội dung Markdown.

## Tóm tắt

Dự án xây dựng ứng dụng ghi chú dùng Express và MongoDB, đóng gói bằng Docker Compose và triển khai lên Ubuntu EC2 qua GitHub Actions. Mục tiêu là tái tạo triển khai, chặn thay đổi không đạt kiểm thử, xác minh phiên bản đang phục vụ và phục hồi sau lỗi vận hành. Bản hoàn thiện bổ sung readiness có kiểm tra DB, build trước thay container, backup có checksum, restore có kiểm tra và ba tình huống lỗi thực nghiệm trong môi trường riêng. Bộ kiểm thử API gồm 10 trường hợp; thực nghiệm vận hành xác minh dữ liệu được khôi phục và hệ thống phục hồi sau lỗi app, DB và cấu hình URI. Hạn chế còn lại gồm một instance duy nhất, thời gian gián đoạn khi thay container, chưa có tài khoản người dùng, và cần xác minh cấu hình CloudWatch/TLS/cron trực tiếp trong AWS.

**Từ khóa:** DevOps, Docker Compose, CI/CD, MongoDB, healthcheck, backup, troubleshooting.

## 1. Bài toán và phạm vi

Một ứng dụng nhỏ vẫn cần quy trình triển khai nhất quán. Nếu cập nhật bằng SSH thủ công, nhóm dễ chạy sai commit hoặc bỏ qua kiểm thử. Nếu kiểm tra sức khỏe chỉ trả một chuỗi tĩnh, ứng dụng có thể báo healthy dù cơ sở dữ liệu không dùng được. Nếu sao lưu chỉ dựa vào dòng thông báo cuối script, một lỗi `mongodump` có thể bị hiểu nhầm là đã bảo vệ dữ liệu.

Smart Note được chọn làm ứng dụng minh họa vì luồng tạo, đọc và xóa dữ liệu đủ để kiểm tra kết nối xuyên suốt từ browser tới DB. Phạm vi là mô hình demo môn học, chưa phải dịch vụ ghi chú cá nhân đa người dùng. Yêu cầu cuối kỳ bao gồm triển khai từ máy sạch, demo commit–pipeline–production, quan sát hệ thống, backup/restore, playbook ít nhất ba tình huống và báo cáo có minh chứng. Phần video nằm ngoài phạm vi thực hiện theo quyết định của người phụ trách dự án.

## 2. Thiết kế hệ thống

Sơ đồ hiện tại nằm ở [architecture](architecture/README.md). Trình duyệt gửi HTTP tới Nginx trên EC2. Nginx proxy tới app ở loopback cổng 3000. Express phục vụ HTML và các API; Mongoose giao tiếp với MongoDB qua DNS service `db` trong mạng Docker. Named volume `mongo_data` giữ dữ liệu qua lần tạo lại container. Cổng DB không publish ra host.

Tách Nginx trên host và app/DB trong container giúp giữ cấu trúc hạ tầng đang dùng ở tuần trước. Docker thay PM2 trong quản lý tiến trình ứng dụng. Tên project Compose phải ổn định để tiếp tục dùng volume cũ. Hệ thống hiện chưa có replica hoặc load balancer; lỗi cả EC2 làm dịch vụ ngừng dù restart policy được bật.

App chạy user không phải root, bỏ Linux capabilities và dùng filesystem chỉ đọc. Giao diện escape dữ liệu trước khi render; API giới hạn kích thước request, độ dài field và loại dữ liệu. Các biện pháp này giảm bề mặt tấn công cơ bản nhưng không thay thế auth, authorization hay TLS. Người dùng Internet vẫn chia sẻ cùng tập ghi chú demo.

## 3. Quy trình phát triển và triển khai

`npm ci` cài theo lockfile đã đồng bộ. Test dùng MongoDB riêng, không lấy URI production. GitHub Actions chạy API test cùng MongoDB 6.0 và chạy một job operations riêng bằng Docker. Job operations tạo project tên `note-check-*`, tự kiểm thử backup/restore và gây lỗi có kiểm soát, sau đó xóa riêng tài nguyên thực nghiệm.

Deploy chỉ thực hiện trên `main` khi cả ba job test, operations và rollback thành công. Workflow truyền SHA đầy đủ cho EC2 và checkout đúng commit đó. Image được gắn SHA để truy vết. Build diễn ra trước khi thay app đang phục vụ, vì vậy lỗi build không chủ động dừng phiên bản cũ. Nếu DB đã chạy, script sao lưu trước khi cập nhật stack. Compose chờ healthy; smoke test kiểm tra DB up, version, API danh sách và homepage.

Nếu kiểm tra sau cập nhật thất bại, script cố chạy lại application image cũ và vẫn trả lỗi cho pipeline. Việc giữ trạng thái failed giúp nhóm nhìn thấy deployment chưa đạt dù người dùng đã được phục hồi về bản cũ. Cơ chế này không rollback schema, dữ liệu hoặc mọi cấu hình hạ tầng. Quy trình không đạt zero downtime: một app container vẫn có thời gian thay thế, và thay cấu hình DB có thể tạo lại DB container. Dùng nhiều replica cùng reverse proxy và migration có kiểm soát là hướng nâng cấp tiếp theo.

## 4. Quan sát và khả năng phục hồi

`/live` đo khả năng tiến trình trả HTTP; `/health` ping DB và trả 503 khi chưa sẵn sàng. Health response chứa version để đối chiếu với commit CI. JSON request log chứa method, path, status, duration và version; không log body/credentials. Docker xoay log với giới hạn 10 MB × 3 file cho mỗi container. Trạng thái unhealthy không tự làm Docker restart, nên monitoring bên ngoài vẫn cần thiết.

CloudWatch có thể cung cấp CPU, network và status checks của EC2. RAM/disk cần CloudWatch Agent. Báo cáo này không khẳng định alarm, agent hay SNS đã được cài trong tài khoản AWS: chưa có quyền truy cập để xác minh trong phiên hoàn thiện. Hướng dẫn trong [operations](operations/README.md) xác định cách tạo alarm và minh chứng cần bổ sung. Tương tự, việc mở cổng 443 chưa chứng minh HTTPS hoạt động.

Backup dùng `mongodump --archive --gzip` stream ra ngoài checkout, tạo checksum SHA256 và trả lỗi khi thao tác thất bại. Restore xác minh checksum trước khi dừng app, khôi phục với `--drop --stopOnError`, sau đó đợi app healthy. Tạm dừng app ngăn writers của chính ứng dụng thay đổi dữ liệu trong lúc restore. Với workload lớn hoặc replica set, cần chiến lược snapshot/oplog phù hợp; backup này chưa cam kết snapshot nhất quán nhiều collection trong điều kiện ghi đồng thời.

Backup trên cùng EC2 hữu ích với lỗi thao tác hoặc mất dữ liệu ứng dụng nhưng không đủ trước mất toàn bộ disk/instance. Cron mẫu đặt lịch hàng ngày; mục tiêu RPO 24 giờ chỉ có ý nghĩa sau khi cron được cài, chạy thành công và được theo dõi. RTO phải đo theo lần khôi phục thực tế; không suy ra SLA từ một lần test nhỏ.

## 5. Phương pháp thực nghiệm

API test kiểm tra tạo/xem/xóa, ID không tồn tại, homepage, readiness khi DB sẵn sàng, input sai, giới hạn độ dài, kiểm soát field do client gửi và trạng thái DB ngắt kết nối. Các test dùng dữ liệu riêng. Jest được giữ tùy chọn VM modules phù hợp với dependency hiện tại, bỏ ép thoát để phát hiện handle chưa giải phóng.

Thực nghiệm Docker dùng cùng Dockerfile và Compose với production, nhưng tên project, container, volume và cổng khác. Script tạo ghi chú có nội dung xác định, backup, xóa, restore và so sánh cả ID lẫn content. Sau đó script làm hỏng archive để xác nhận checksum chặn restore trước khi ảnh hưởng app. Ba tình huống sự cố lần lượt là app stopped, DB stopped và URI sai. Mỗi lần xác minh dấu hiệu lỗi rồi khôi phục và chạy smoke test.

## 6. Kết quả và minh chứng

| Thực nghiệm | Kết quả quan sát |
|---|---|
| API suite | 10/10 trường hợp đạt trên môi trường kiểm tra |
| Cài dependency | `npm ci` thành công sau đồng bộ lockfile |
| Dependency production | `npm audit --omit=dev`: 0 lỗ hổng được registry báo tại thời điểm kiểm tra |
| Docker image | Build thành công; app chạy với healthcheck và DB thật |
| Backup → xóa → restore | Đọc lại đúng ID và nội dung ban đầu |
| Archive bị thay đổi | Restore bị từ chối, app vẫn truy cập được |
| App stopped | Kết nối thất bại, phục hồi thành công sau start/up |
| DB stopped | Readiness 503; backup thất bại; phục hồi DB/API thành công |
| URI sai | App không healthy, log lỗi kết nối; sửa URI và recreate phục hồi |
| Deploy image lỗi readiness | Pipeline trả lỗi và khôi phục image/version trước, giữ dữ liệu và cấu hình |

Xem [Week 4 evidence](../evidence/week-4/README.md) và artifact Actions để phân biệt kết quả kiểm tra độc lập với production. Việc pipeline hoặc script in “success” không tự chứng minh Nginx, CloudWatch, backup cron hay dữ liệu production đã được xác minh. Deployment cuối cần đối chiếu SHA trên HTTP và kết quả Actions tương ứng.

Thử nghiệm rollout/rollback ban đầu bị giới hạn dung lượng Docker cloud, sau đó được xác minh thành công trên GitHub Actions run 42968497856: candidate trả 503 bị từ chối, phiên bản trước, dữ liệu và cấu hình được phục hồi. Bản hoàn thiện được chuẩn bị trên nhánh riêng để review, chưa xác minh deployment mới vì kết nối hiện tại chưa có quyền ghi repo gốc (HTTP 403).

## 7. Đánh giá và hạn chế

Kết quả cho thấy hệ thống phát hiện được lỗi dependency DB mà healthcheck tĩnh trước đây bỏ sót; backup/restore có kiểm chứng dữ liệu và failure path; và quy trình triển khai kiểm tra đúng phiên bản sau thay đổi. Tài liệu clean-server và playbook giúp nhóm tái tạo và giải thích vận hành.

Thực nghiệm chỉ dùng tập dữ liệu nhỏ, không chứng minh năng lực tải, độ bền backup dài hạn hoặc high availability. Chưa có load test, threat model đầy đủ, tài khoản/phân quyền hoặc TLS được xác nhận. MongoDB 6.0 đã hết vòng đời hỗ trợ nhưng được giữ nhằm tránh thay đổi major trực tiếp trên dữ liệu hiện hữu; nâng cấp cần kế hoạch theo tài liệu MongoDB và diễn tập khôi phục. Node/Actions được chọn theo version tag nên cần pin digest/commit nếu yêu cầu tái lập tuyệt đối.

Phân công trong README là phân công nhóm ban đầu. Nhóm cần tự đối chiếu thay đổi mới với người phụ trách, lịch sử công việc và năng lực trả lời Q&A. Không dùng báo cáo này để khẳng định mọi thành viên đã trực tiếp hoàn tất các thao tác chưa được xác minh.

## 8. Kết luận

Smart Note có luồng phát triển, kiểm thử, đóng gói, triển khai và phục hồi phù hợp mô hình bài tập DevOps. Bản hoàn thiện bổ sung các kiểm tra có thể lặp lại và ghi rõ ranh giới chứng cứ. Trước bảo vệ cần xác nhận CloudWatch/cron/security trên EC2, thực hiện một lượt live demo, chốt phiên bản release và kiểm tra khả năng trình bày của từng thành viên.

## Tài liệu tham khảo

1. Docker Compose, startup order và healthcheck: https://docs.docker.com/compose/how-tos/startup-order/
2. Docker Compose CLI: https://docs.docker.com/reference/cli/docker/compose/up/
3. GitHub Actions workflows: https://docs.github.com/en/actions/writing-workflows
4. MongoDB Database Tools: https://www.mongodb.com/docs/database-tools/
5. Amazon EC2 monitoring: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/monitoring_ec2.html
6. Express security: https://expressjs.com/en/advanced/best-practice-security.html
