require("dotenv").config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const http = require('http');
const WebSocket = require('ws');
const url = require('url');
const { db } = require('./firebaseConfig');
const admin = require('firebase-admin'); // ✅ تم الإصلاح: إضافة تعريف admin

// استيراد المسارات
const propertiesRoutes = require('./routes/properties');
const authRoutes = require('./routes/auth');
const usersRoutes = require('./routes/users');
const adminRoutes = require('./routes/admin');
const chatRoutes = require('./routes/chats');
const dealRoutes = require('./routes/deals');
const reportsRoutes = require('./routes/reports');

const app = express();
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
// 2. Middleware
// ==========================================
app.use((req, res, next) => {
  req.sendToUser = sendToUser;
  next();
});

app.use((req, res, next) => {
  console.log(`\n🔔 [SERVER HIT] ${req.method} ${req.url}`);
  next();
});

// ==========================================
// 3. ربط مسارات API
// ==========================================
app.use('/api/properties', propertiesRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/chats', chatRoutes);
app.use('/api/deals', dealRoutes);
app.use('/api/reports', reportsRoutes);

app.get('/', (req, res) => {
  res.status(200).send('🚀 Aqar Proxy Server is Running with WebSocket!');
});

// ==========================================
// 4. تشغيل السيرفر وإعداد WebSocket
// ==========================================
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

wss.on('connection', async (ws, req) => {
  const parameters = url.parse(req.url, true).query;
  const userId = parameters.userId;
  const token = parameters.token;

  // التحقق من التوكن
  if (!token) {
    console.log('❌ [WebSocket] No token provided');
    ws.close(4001, "Unauthorized");
    return;
  }

  try {
    // ✅ الآن هذا السطر سيعمل بشكل صحيح لأن admin تم تعريفه
    await admin.auth().verifyIdToken(token);
  } catch (e) {
    console.error("❌ [WebSocket] Token invalid:", e.message);
    ws.close(4001, "Unauthorized");
    return;
  }

  if (userId) {
    clients.set(userId, ws);
    console.log(`✅ [WebSocket] User connected: ${userId}`);
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
      console.error('❌ [WebSocket] Message Error:', e);
    }
  });

  ws.on('close', () => {
    if (userId) {
      clients.delete(userId);
      console.log(`❌ [WebSocket] User disconnected: ${userId}`);
    }
  });
});

const PORT = process.env.PORT || 3001;
server.listen(PORT, () => {
  console.log(`✅ Server is running on port ${PORT}`);
  console.log('✅ WebSocket Server is ready 🔌');
});