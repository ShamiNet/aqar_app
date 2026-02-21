require("dotenv").config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const http = require('http');
const WebSocket = require('ws');
const url = require('url');
const { db } = require('./firebaseConfig');
const admin = require('firebase-admin'); // ✅ تم الإصلاح: إضافة تعريف admin
const redis = require('redis'); // ✅ إضافة مكتبة Redis

// استيراد المسارات
const propertiesRoutes = require('./routes/properties');
const authRoutes = require('./routes/auth');
const usersRoutes = require('./routes/users');
const adminRoutes = require('./routes/admin');
const chatRoutes = require('./routes/chats');
const dealRoutes = require('./routes/deals');
const reportsRoutes = require('./routes/reports');

const app = express();
app.set('trust proxy', 1);
app.use(cors());
app.use(bodyParser.json());

// ==========================================
// 1. إعداد متغيرات WebSocket
// ==========================================
const clients = new Map();

function sendToUser(targetUserId, message) {
  const client = clients.get(targetUserId);
  if (client && client.readyState === WebSocket.OPEN) {
    client.send(JSON.stringify(message));
    return true;
  }
  return false;
}

// ==========================================
// 2. إعداد Redis (التخزين المؤقت)
// ==========================================
const redisClient = redis.createClient({
    // تأكد من ضبط رابط Redis في ملف .env إذا كان مختلفاً
    url: process.env.REDIS_URL || 'redis://127.0.0.1:6379'
});

redisClient.on('error', (err) => console.error('❌ [Redis] خطأ في الاتصال:', err));
redisClient.on('connect', () => console.log('✅ [Redis] تم الاتصال بنجاح ⚡'));

// الاتصال بخادم Redis
(async () => {
    await redisClient.connect();
})();

// ==========================================
// 3. Middleware
// ==========================================
app.use((req, res, next) => {
  req.sendToUser = sendToUser;
  // ✅ تمرير كائن Redis لجميع الطلبات لسهولة استخدامه في ملفات المسارات الأخرى
  req.redisClient = redisClient; 
  next();
});

app.use((req, res, next) => {
  console.log(`\n🔔 [SERVER HIT] ${req.method} ${req.url}`);
  next();
});

// ==========================================
// 4. ربط مسارات API
// ==========================================
app.use('/api/properties', propertiesRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/chats', chatRoutes);
app.use('/api/deals', dealRoutes);
app.use('/api/reports', reportsRoutes);

app.get('/', (req, res) => {
  res.status(200).send('🚀 Aqar Proxy Server is Running with WebSocket & Redis!');
});

// ==========================================
// 5. تشغيل السيرفر وإعداد WebSocket
// ==========================================
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

wss.on('connection', async (ws, req) => {
  const parameters = url.parse(req.url, true).query;
  const userId = parameters.userId;
  const token = parameters.token;

  // التحقق من التوكن
  if (!token) {
    console.log('❌ [WebSocket] لم يتم تقديم توكن');
    ws.close(4001, "Unauthorized");
    return;
  }

  try {
    // ✅ التحقق من صحة التوكن عبر Firebase Admin
    await admin.auth().verifyIdToken(token);
  } catch (e) {
    console.error("❌ [WebSocket] التوكن غير صالح:", e.message);
    ws.close(4001, "Unauthorized");
    return;
  }

  if (userId) {
    clients.set(userId, ws);
    console.log(`✅ [WebSocket] متصل: ${userId}`);
  }

  ws.on('message', async (message) => {
    try {
      const data = JSON.parse(message);
      if (data.type === 'get_chats' && userId) {
        ws.send(JSON.stringify({
          type: 'chats_update',
          chats: []
        }));
      }
    } catch (e) {
      console.error('❌ [WebSocket] خطأ في الرسالة:', e);
    }
  });

  ws.on('close', () => {
    if (userId) {
      clients.delete(userId);
      console.log(`❌ [WebSocket] غير متصل: ${userId}`);
    }
  });
});

const PORT = process.env.PORT || 3001;
server.listen(PORT, () => {
  console.log(`✅ Server is running on port ${PORT}`);
  console.log('✅ WebSocket Server is ready 🔌');
});