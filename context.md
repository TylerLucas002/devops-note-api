This file is a merged representation of the entire codebase, combined into a single document by Repomix.

# File Summary

## Purpose
This file contains a packed representation of the entire repository's contents.
It is designed to be easily consumable by AI systems for analysis, code review,
or other automated processes.

## File Format
The content is organized as follows:
1. This summary section
2. Repository information
3. Directory structure
4. Repository files (if enabled)
5. Multiple file entries, each consisting of:
  a. A header with the file path (## File: path/to/file)
  b. The full contents of the file in a code block

## Usage Guidelines
- This file should be treated as read-only. Any changes should be made to the
  original repository files, not this packed version.
- When processing this file, use the file path to distinguish
  between different files in the repository.
- Be aware that this file may contain sensitive information. Handle it with
  the same level of security as you would the original repository.

## Notes
- Some files may have been excluded based on .gitignore rules and Repomix's configuration
- Binary files are not included in this packed representation. Please refer to the Repository Structure section for a complete list of file paths, including binary files
- Files matching patterns in .gitignore are excluded
- Files matching default ignore patterns are excluded
- Files are sorted by Git change count (files with more changes are at the bottom)

# Directory Structure
```
.github/
  workflows/
    deploy.yml
architecture/
  architecture explain.md
  test.drawio.png
week 1/
  report1.2.png
  report1.3.png
  report1.png
  week-1-explanation.md
.gitignore
api.test.js
docker-compose.yml
Dockerfile
index.html
package.json
README.md
server.js
```

# Files

## File: architecture/architecture explain.md
```markdown
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
```

## File: week 1/week-1-explanation.md
```markdown
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
```

## File: .gitignore
```
node_modules/
.env
```

## File: Dockerfile
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

## File: index.html
```html
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <title>DevOps Smart Note App</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f4f7f6; padding: 20px; }
        .container { max-width: 600px; margin: auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); }
        h2 { text-align: center; color: #333; }
        input, textarea { width: 100%; margin-bottom: 15px; padding: 10px; border: 1px solid #ccc; border-radius: 4px; box-sizing: border-box; }
        button { width: 100%; padding: 10px; background: #28a745; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }
        button:hover { background: #218838; }
        .note { background: #e9ecef; padding: 15px; margin-top: 15px; border-radius: 4px; border-left: 5px solid #007bff; }
        .note h4 { margin: 0 0 5px 0; color: #007bff; }
        .note p { margin: 0; color: #555; }
    </style>
</head>
<body>
    <div class="container">
        <h2>📝 Smart Note - DevOps Week 1</h2>
        <input type="text" id="title" placeholder="Nhập tiêu đề ghi chú..." required>
        <textarea id="content" rows="4" placeholder="Nhập nội dung..." required></textarea>
        <button onclick="saveNote()">Lưu Ghi Chú</button>

        <div id="notes-list"></div>
    </div>

    <script>
        // Hàm load dữ liệu từ API
        async function fetchNotes() {
            const response = await fetch('/notes');
            const notes = await response.json();
            const list = document.getElementById('notes-list');
            list.innerHTML = '';
            notes.forEach(note => {
                list.innerHTML += `
                    <div class="note">
                        <h4>${note.title}</h4>
                        <p>${note.content}</p>
                    </div>`;
            });
        }

        // Hàm lưu dữ liệu
        async function saveNote() {
            const title = document.getElementById('title').value;
            const content = document.getElementById('content').value;
            if(!title || !content) return alert("Vui lòng nhập đủ thông tin!");

            await fetch('/notes', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ title, content })
            });
            
            document.getElementById('title').value = '';
            document.getElementById('content').value = '';
            fetchNotes(); // Tải lại danh sách
        }

        fetchNotes(); // Chạy ngay khi mở web
    </script>
</body>
</html>
```

## File: README.md
```markdown
# DevOps Final Project: Smart Note API

**Môn học:** DevOps - Học kỳ 2026
**Nhóm:** Làng Xì Mi
**Thành viên:**
1. **Nguyễn Bá Toàn:** Thiết kế kiến trúc hạ tầng, thiết lập Server Ubuntu, cấu hình UFW Firewall và Nginx.
2. **Trần Tiến Minh:** Xây dựng backend Node.js (Express), kết nối và cấu hình mô hình dữ liệu.
3. **Hồ Thăng Bảo Huy:** Cài đặt MongoDB, thiết lập PM2, cấu hình Git repo và kiểm thử bằng Postman.

## Hướng dẫn triển khai thủ công (Week 1)
1. Clone source code: `git clone <repository_url>`
2. Cài đặt các dependencies: `sudo apt install nginx mongodb` và Node.js.
3. Vào thư mục dự án chạy: `npm install`
4. Khởi chạy ứng dụng: `pm2 start server.js --name note-api`
5. Cấu hình Nginx proxy_pass về `localhost:3000` và khởi động lại Nginx.
```

## File: docker-compose.yml
```yaml
version: '3.8'
services:
  app:
    build: .
    container_name: note-api-app
    restart: always
    ports:
      - "3000:3000"
    environment:
      - MONGO_URI=mongodb://db:27017/notedb
    depends_on:
      - db
    networks:
      - note-network

  db:
    image: mongo:6.0
    container_name: note-api-db
    restart: always
    volumes:
      - mongo_data:/data/db
    networks:
      - note-network

networks:
  note-network:
    driver: bridge

volumes:
  mongo_data:
```

## File: server.js
```javascript
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');

const app = express();
app.use(express.json());
app.use(cors());
app.use(express.static('public'));

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// Sử dụng biến môi trường cho Database
const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/notedb';
if (process.env.NODE_ENV !== 'test') {
  mongoose.connect(MONGO_URI)
    .then(() => console.log('✅ Connected to MongoDB'))
    .catch(err => console.error('❌ Database connection error:', err));
}

const Note = mongoose.model('Note', new mongoose.Schema({
  title: String,
  content: String,
  createdAt: { type: Date, default: Date.now }
}));

app.get('/notes', async (req, res) => {
  try {
    const notes = await Note.find().sort({ createdAt: -1 });
    res.json(notes);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/notes', async (req, res) => {
  try {
    const newNote = await Note.create(req.body);
    res.status(201).json(newNote);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Phục vụ chạy Test: Chỉ listen khi không bị require bởi Jest
if (require.main === module) {
  app.listen(3000, () => console.log('🚀 API Server running on port 3000'));
}
module.exports = app;
```

## File: package.json
```json
{
  "name": "note-api",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "test": "node --experimental-vm-modules node_modules/jest/bin/jest.js --forceExit"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "type": "commonjs",
  "dependencies": {
    "cors": "^2.8.6",
    "express": "^5.3.0",
    "mongoose": "^9.11.4"
  },
  "devDependencies": {
    "jest": "^30.5.2",
    "mongodb-memory-server": "^11.3.0",
    "supertest": "^7.3.1"
  }
}
```

## File: api.test.js
```javascript
process.env.NODE_ENV = 'test';
const request = require('supertest');
const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');
const app = require('./server');

let mongoServer;

// Tăng thời gian chờ cho Jest khi khởi tạo MongoDB RAM
jest.setTimeout(60000);

// Khởi tạo kết nối DB trước khi test: ưu tiên MONGO_URI, fallback về RAM DB
beforeAll(async () => {
  if (process.env.MONGO_URI) {
    await mongoose.connect(process.env.MONGO_URI);
  } else {
    mongoServer = await MongoMemoryServer.create();
    const uri = mongoServer.getUri();
    await mongoose.connect(uri);
  }
});

// Ngắt kết nối và giải phóng tài nguyên sau khi test xong
afterAll(async () => {
  await mongoose.disconnect();
  if (mongoServer) {
    await mongoServer.stop();
  }
});

describe('GET /notes', () => {
  it('should return a list of notes or empty array with status 200', async () => {
    const res = await request(app).get('/notes');
    expect(res.statusCode).toEqual(200);
    expect(Array.isArray(res.body)).toBeTruthy();
  });
});

describe('POST /notes', () => {
  it('should create a new note with status 201', async () => {
    const noteData = { title: 'Test Note CI/CD', content: 'Testing automated workflow' };
    const res = await request(app).post('/notes').send(noteData);
    expect(res.statusCode).toEqual(201);
    expect(res.body.title).toEqual(noteData.title);
    expect(res.body.content).toEqual(noteData.content);
    expect(res.body).toHaveProperty('_id');
  });
});
```

## File: .github/workflows/deploy.yml
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ "main" ]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      mongodb:
        image: mongo:6.0
        ports:
          - 27017:27017
        options: >-
          --health-cmd mongosh
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm install

      - name: Run Automated Tests
        run: npm test
        env:
          MONGO_URI: mongodb://127.0.0.1:27017/notedb_test

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to EC2
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          script: |
            cd ~/devops-note-api
            git pull origin main
            sudo docker compose up -d --build
```
