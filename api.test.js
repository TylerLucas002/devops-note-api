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
    const noteData = { title: 'Test Note CI/CD', content: 'Testing automated workflow', category: 'DevOps' };
    const res = await request(app).post('/notes').send(noteData);
    expect(res.statusCode).toEqual(201);
    expect(res.body.title).toEqual(noteData.title);
    expect(res.body.content).toEqual(noteData.content);
    expect(res.body.category).toEqual('DevOps');
    expect(res.body).toHaveProperty('_id');
  });
});

describe('DELETE /notes/:id', () => {
  it('should delete an existing note with status 200', async () => {
    const noteRes = await request(app)
      .post('/notes')
      .send({ title: 'Temporary Note', content: 'To be deleted' });
    const noteId = noteRes.body._id;

    const res = await request(app).delete(`/notes/${noteId}`);
    expect(res.statusCode).toEqual(200);
    expect(res.body.message).toContain('thành công');
  });

  it('should return 404 when deleting a non-existent note', async () => {
    const fakeId = new mongoose.Types.ObjectId();
    const res = await request(app).delete(`/notes/${fakeId}`);
    expect(res.statusCode).toEqual(404);
  });
});
describe('Operational and input contracts', () => {
  it('serves the homepage from public/', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toContain('text/html');
  });
  it('reports readiness after pinging MongoDB', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body).toMatchObject({ status: 'OK', database: 'up' });
    expect(res.body.version).toBeTruthy();
  });
  it('rejects missing or invalid note fields', async () => {
    for (const data of [{}, { title: ' ', content: 'x' }, { title: {}, content: 'x' }, { title: 'x', content: 'y', category: {} }]) {
      expect((await request(app).post('/notes').send(data)).statusCode).toBe(400);
    }
  });
  it('rejects oversized titles and malformed IDs', async () => {
    expect((await request(app).post('/notes').send({title:'x'.repeat(201),content:'x'})).statusCode).toBe(400);
    expect((await request(app).delete('/notes/not-an-id')).statusCode).toBe(400);
  });
  it('does not allow clients to assign IDs or creation dates', async () => {
    const id = new mongoose.Types.ObjectId().toString();
    const res = await request(app).post('/notes').send({title:'safe',content:'safe',_id:id,createdAt:'2000-01-01'});
    expect(res.statusCode).toBe(201);
    expect(res.body._id).not.toBe(id);
    expect(res.body.createdAt).not.toContain('2000-01-01');
  });
  it('keeps liveness up but readiness and data requests fail when DB disconnects', async () => {
    await mongoose.disconnect();
    try {
      expect((await request(app).get('/live')).statusCode).toBe(200);
      const health = await request(app).get('/health');
      expect(health.statusCode).toBe(503);
      expect(health.body.database).toBe('down');
      expect((await request(app).get('/notes')).statusCode).toBe(503);
    } finally {
      await mongoose.connect(process.env.MONGO_URI || mongoServer.getUri());
    }
  });
});
