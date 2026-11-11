const express = require('express');
const mongoose = require('mongoose');
const path = require('path');

const app = express();
const version = process.env.APP_VERSION || 'development';
app.disable('x-powered-by');
app.use(express.json({ limit: '32kb' }));
app.use((req, res, next) => {
  const started = Date.now();
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'same-origin');
  res.on('finish', () => {
    if (process.env.NODE_ENV !== 'test') console.log(JSON.stringify({
      time: new Date().toISOString(), method: req.method, path: req.path,
      status: res.statusCode, durationMs: Date.now() - started, version
    }));
  });
  next();
});
app.use(express.static(path.join(__dirname, 'public')));

// Liveness only: the Node process can answer HTTP requests.
app.get('/live', (req, res) => res.json({ status: 'OK', version }));
// Readiness: verify a real database operation, not only the HTTP process.
app.get('/health', async (req, res) => {
  res.set('Cache-Control', 'no-store');
  try {
    if (mongoose.connection.readyState !== 1) throw new Error('Database unavailable');
    await mongoose.connection.db.admin().ping({ timeoutMS: 2000 });
    res.json({ status: 'OK', database: 'up', version, timestamp: new Date() });
  } catch {
    res.status(503).json({ status: 'DEGRADED', database: 'down', version, timestamp: new Date() });
  }
});

mongoose.set('bufferCommands', false);
const Note = mongoose.model('Note', new mongoose.Schema({
  title: { type: String, required: true, trim: true, maxlength: 200 },
  content: { type: String, required: true, trim: true, maxlength: 10000 },
  category: { type: String, default: 'Chung', maxlength: 50 },
  createdAt: { type: Date, default: Date.now }
}));
app.use('/notes', (req, res, next) => {
  if (mongoose.connection.readyState !== 1) return res.status(503).json({ error: 'Database unavailable' });
  next();
});
app.get('/notes', async (req, res, next) => {
  try { res.json(await Note.find().sort({ createdAt: -1 })); } catch (err) { next(err); }
});
app.post('/notes', async (req, res, next) => {
  const { title, content, category } = req.body || {};
  if (typeof title !== 'string' || !title.trim() || typeof content !== 'string' || !content.trim() ||
      (category !== undefined && typeof category !== 'string')) {
    return res.status(400).json({ error: 'Title and content must be non-empty strings; category must be a string' });
  }
  try { res.status(201).json(await Note.create({ title, content, category })); } catch (err) { next(err); }
});
app.delete('/notes/:id', async (req, res, next) => {
  if (!mongoose.isObjectIdOrHexString(req.params.id)) return res.status(400).json({ error: 'Invalid note ID' });
  try {
    const note = await Note.findByIdAndDelete(req.params.id);
    if (!note) return res.status(404).json({ error: 'Không tìm thấy ghi chú' });
    res.json({ message: 'Xóa ghi chú thành công', id: req.params.id });
  } catch (err) { next(err); }
});
app.use((err, req, res, next) => {
  if (err.name === 'ValidationError' || err.type === 'entity.parse.failed') return res.status(400).json({ error: 'Invalid request data' });
  if (err.type === 'entity.too.large') return res.status(413).json({ error: 'Request too large' });
  console.error(JSON.stringify({ event: 'request_failed', type: err.name }));
  res.status(500).json({ error: 'Internal server error' });
});

if (require.main === module) {
  const server = app.listen(process.env.PORT || 3000, () => console.log(JSON.stringify({ event: 'listening', version })));
  mongoose.connect(process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/notedb', {
    serverSelectionTimeoutMS: 2000, connectTimeoutMS: 2000, heartbeatFrequencyMS: 1000
  }).then(() => console.log(JSON.stringify({ event: 'database_connected' })))
    .catch(() => { console.error(JSON.stringify({ event: 'database_connection_failed' })); server.close(() => process.exit(1)); });
  const shutdown = () => {
    const timeout = setTimeout(() => process.exit(1), 10000).unref();
    server.close(async () => { await mongoose.disconnect(); clearTimeout(timeout); process.exit(0); });
  };
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}
module.exports = app;
