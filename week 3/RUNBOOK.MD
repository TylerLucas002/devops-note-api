# Runbook: Xử lý sự cố (Incident Response)

Tài liệu hướng dẫn nhanh cách phát hiện, điều tra và khắc phục các sự cố thường gặp của hệ thống `note-api`.

## Mục lục

- [Incident 1: Mất kết nối Database](#incident-1-mất-kết-nối-database-container-db-bị-sập)
- [Incident 2: Quá tải CPU máy chủ](#incident-2-quá-tải-cpu-máy-chủ-cpu-alert)

---

## Incident 1: Mất kết nối Database (Container DB bị sập)

### Triệu chứng

- Người dùng vào web thấy trang quay vòng vòng (loading mãi).
- API trả về lỗi `500`.
- Chạy `docker ps` không thấy container `note-api-db`.

### Điều tra

Xem log của container database:

```bash
docker logs note-api-db
```

### Khắc phục

1. Khởi động lại service database:

   ```bash
   docker compose restart db
   ```

2. Nếu dữ liệu bị lỗi, khôi phục từ bản sao lưu gần nhất:

   ```bash
   ./restore.sh
   ```

---

## Incident 2: Quá tải CPU máy chủ (CPU Alert)

### Triệu chứng

- Nhận email cảnh báo từ AWS CloudWatch: `CPU utilization > 70%`.
- Web phản hồi rất chậm.

### Điều tra

1. SSH vào EC2, kiểm tra container nào đang tốn nhiều CPU:

   ```bash
   htop
   # hoặc
   docker stats
   ```

2. Theo dõi log của ứng dụng theo thời gian thực:

   ```bash
   docker logs -f note-api-app
   ```

### Khắc phục

**Tạm thời:** restart service web.

```bash
docker compose restart app
```

**Lâu dài:**

- Tối ưu mã nguồn, xử lý memory leak.
- Nâng cấp RAM/CPU cho máy chủ.

---

## Tóm tắt nhanh

| Incident | Dấu hiệu chính | Lệnh điều tra | Lệnh khắc phục |
|---|---|---|---|
| DB sập | Lỗi 500, không thấy `note-api-db` trong `docker ps` | `docker logs note-api-db` | `docker compose restart db` / `./restore.sh` |
| CPU cao | Email CloudWatch, web chậm | `htop`, `docker stats`, `docker logs -f note-api-app` | `docker compose restart app` |
