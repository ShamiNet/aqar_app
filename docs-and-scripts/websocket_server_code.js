// ==================== WebSocket للتحديثات الفورية ====================
// أضف هذا في ملف index.js بعد إعداد Express

const WebSocket = require('ws');
const url = require('url');

// إنشاء WebSocket Server
const wss = new WebSocket.Server({ noServer: true });

// تخزين الاتصالات النشطة
const clients = new Map(); // userId -> WebSocket

wss.on('connection', (ws, request, userId) => {
  console.log(`✅ [WebSocket] User ${userId} connected`);
  
  // حفظ الاتصال
  clients.set(userId, ws);

  // إرسال المحادثات الأولية
  sendChatsToUser(userId);

  // الاستماع للرسائل من العميل
  ws.on('message', async (message) => {
    try {
      const data = JSON.parse(message.toString());
      console.log(`📨 [WebSocket] Message from ${userId}:`, data.type);
      
      if (data.type === 'get_chats') {
        await sendChatsToUser(userId);
      }
    } catch (error) {
      console.error('❌ [WebSocket] Error handling message:', error);
    }
  });

  // عند قطع الاتصال
  ws.on('close', () => {
    console.log(`🔌 [WebSocket] User ${userId} disconnected`);
    clients.delete(userId);
  });

  ws.on('error', (error) => {
    console.error(`❌ [WebSocket] Error for user ${userId}:`, error);
    clients.delete(userId);
  });
});

// دالة لإرسال المحادثات للمستخدم
async function sendChatsToUser(userId) {
  try {
    const ws = clients.get(userId);
    if (!ws || ws.readyState !== WebSocket.OPEN) return;

    // جلب المحادثات من Firestore
    const chatsSnapshot = await db.collection('chats')
      .where('participants', 'array-contains', userId)
      .orderBy('lastMessageTimestamp', 'desc')
      .limit(50)
      .get();

    const chats = [];
    for (const doc of chatsSnapshot.docs) {
      const data = doc.data();
      chats.push({
        id: doc.id,
        ...data
      });
    }

    // إرسال البيانات
    ws.send(JSON.stringify({
      type: 'chats_update',
      chats: chats
    }));

    console.log(`📤 [WebSocket] Sent ${chats.length} chats to user ${userId}`);
  } catch (error) {
    console.error('❌ [WebSocket] Error sending chats:', error);
  }
}

// دالة لإشعار المستخدمين بتحديث المحادثة
function notifyChatUpdate(chatId, participantIds) {
  console.log(`🔔 [WebSocket] Notifying users about chat ${chatId}`);
  
  participantIds.forEach(async (userId) => {
    await sendChatsToUser(userId);
  });
}

// دمج WebSocket مع HTTP Server
server.on('upgrade', (request, socket, head) => {
  const pathname = url.parse(request.url).pathname;
  
  if (pathname === '/') {
    // استخراج userId و token من query parameters
    const params = url.parse(request.url, true).query;
    const userId = params.userId;
    const token = params.token;

    if (!userId || !token) {
      console.log('⚠️ [WebSocket] Missing userId or token');
      socket.destroy();
      return;
    }

    // يمكنك إضافة التحقق من الـ token هنا
    // ...

    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit('connection', ws, request, userId);
    });
  } else {
    socket.destroy();
  }
});

// استخدام notifyChatUpdate عند إرسال رسالة جديدة
// مثلاً في endpoint إرسال الرسائل:
// router.post('/chats/:chatId/messages', async (req, res) => {
//   // ... كود حفظ الرسالة
//   
//   // إشعار المستخدمين
//   const chatDoc = await db.collection('chats').doc(chatId).get();
//   const participants = chatDoc.data().participants;
//   notifyChatUpdate(chatId, participants);
// });

module.exports = { notifyChatUpdate };
