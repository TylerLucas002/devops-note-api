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

// 🌟 ĐOẠN CODE THÊM MỚI CHO TUẦN 3: API Health Check
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    message: 'API is running smoothly',
    timestamp: new Date()
  });
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
  category: { type: String, default: 'Chung' },
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

app.delete('/notes/:id', async (req, res) => {
  try {
    const note = await Note.findByIdAndDelete(req.params.id);
    if (!note) {
      return res.status(404).json({ error: 'Không tìm thấy ghi chú' });
    }
    res.json({ message: 'Xóa ghi chú thành công', id: req.params.id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Phục vụ chạy Test: Chỉ listen khi không bị require bởi Jest
if (require.main === module) {
  app.listen(3000, () => console.log('🚀 API Server running on port 3000'));
}
module.exports = app;