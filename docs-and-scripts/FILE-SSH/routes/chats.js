const express = require('express');
const router = express.Router();
const { db } = require('../firebaseConfig');
const admin = require('firebase-admin');

// 1. بدء محادثة جديدة (POST /api/chats)
router.post('/', async (req, res) => {
  try {
    const { propertyId, participants } = req.body;

    if (!participants || !Array.isArray(participants) || participants.length < 2) {
        return res.status(400).json({ error: 'Participants array is required and must contain at least 2 users.' });
    }

    const snapshot = await db.collection('chats')
      .where('propertyId', '==', propertyId)
      .get();

    let existingChatId = null;

    snapshot.forEach(doc => {
        const data = doc.data();
        if (data.participants && Array.isArray(data.participants)) {
            const isSameChat = participants.every(uid => data.participants.includes(uid));
            if (isSameChat) existingChatId = doc.id;
        }
    });

    if (existingChatId) {
        return res.status(200).json({ chatId: existingChatId, isNew: false });
    }

    // ✅ التعديل هنا: جلب الأسماء الحقيقية للمستخدمين بدلاً من الأسماء الافتراضية
    const participantNames = {};
    for (const uid of participants) {
        try {
            const userDoc = await db.collection('users').doc(uid).get();
            if (userDoc.exists) {
                participantNames[uid] = userDoc.data().username || 'مستخدم';
            } else {
                participantNames[uid] = 'مستخدم';
            }
        } catch (error) {
            console.error(`Error fetching user ${uid}:`, error);
            participantNames[uid] = 'مستخدم';
        }
    }

    const newChat = {
        propertyId,
        participants,
        participantNames: participantNames, // استخدام الأسماء المجلوبة
        lastMessage: '',
        lastMessageTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const docRef = await db.collection('chats').add(newChat);
    res.status(201).json({ chatId: docRef.id, participantNames: newChat.participantNames, ...newChat, isNew: true });

  } catch (error) {
    console.error('Error starting chat:', error);
    res.status(500).json({ error: error.message });
  }
});

// 2. جلب محادثات المستخدم مع حساب الرسائل غير المقروءة (GET /api/chats?userId=...)
router.get('/', async (req, res) => {
    try {
        const userId = req.query.userId;

        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }
        const snapshot = await db.collection('chats')
            .where('participants', 'array-contains', userId)
            .orderBy('lastMessageTimestamp', 'desc')
            .get();

        const chats = [];
        
        // ✅ حساب عدد الرسائل غير المقروءة لكل محادثة
        for (const doc of snapshot.docs) {
            const chatData = doc.data();
            const chatId = doc.id;
            
            // جلب آخر وقت قراءة للمستخدم
            const lastReadTime = chatData[`lastRead_${userId}`] || null;
            
            // حساب عدد الرسائل غير المقروءة (طريقة مبسطة)
            let unreadCount = 0;
            try {
                const allMessages = await db.collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('createdAt', 'desc')
                    .get();
                
                // عد الرسائل غير المقروءة يدوياً
                allMessages.forEach(msgDoc => {
                    const msgData = msgDoc.data();
                    const msgSenderId = msgData.senderId;
                    const msgTime = msgData.createdAt;
                    
                    // إذا لم يكن المرسل هو المستخدم الحالي
                    if (msgSenderId && msgSenderId !== userId) {
                        // إذا لم يكن هناك وقت قراءة، أو الرسالة أحدث من آخر قراءة
                        if (!lastReadTime || (msgTime && msgTime.toMillis() > lastReadTime.toMillis())) {
                            unreadCount++;
                        }
                    }
                });
            } catch (countError) {
                console.error(`Error counting unread for chat ${chatId}:`, countError);
                unreadCount = 0;
            }
            
            chats.push({ 
                id: chatId, 
                ...chatData,
                unreadCount: unreadCount 
            });
        }
        
        res.json(chats);
    } catch (error) {
        console.error('Error fetching chats:', error);
        res.status(500).json({ error: error.message });
    }
});

// 3. جلب معلومات محادثة واحدة (GET /api/chats/:chatId)
router.get('/:chatId', async (req, res) => {
    try {
        const { chatId } = req.params;
        const chatDoc = await db.collection('chats').doc(chatId).get();

        if (!chatDoc.exists) {
            return res.status(404).json({ error: 'Chat not found' });
        }

        const chatData = chatDoc.data();
        const participants = chatData.participants || [];

        const participantNames = {};
        for (const userId of participants) {
            const userDoc = await db.collection('users').doc(userId).get();
            participantNames[userId] = userDoc.data()?.username || 'مستخدم';
        }

        res.json({
            id: chatDoc.id,
            participantNames,
            ...chatData
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 4. جلب رسائل محادثة (GET /api/chats/:id/messages)
router.get('/:id/messages', async (req, res) => {
    try {
        const snapshot = await db.collection('chats').doc(req.params.id)
            .collection('messages')
            .orderBy('createdAt', 'desc')
            .get();

        const messages = [];
        snapshot.forEach(doc => messages.push({ id: doc.id, ...doc.data() }));
        res.json(messages);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 4.1. تحديد المحادثة كمقروءة (POST /api/chats/:id/mark-as-read)
router.post('/:id/mark-as-read', async (req, res) => {
    try {
        const chatId = req.params.id;
        const { userId } = req.body;
        
        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }
        
        // تحديث وقت آخر قراءة للمستخدم
        await db.collection('chats').doc(chatId).update({
            [`lastRead_${userId}`]: admin.firestore.FieldValue.serverTimestamp()
        });
        
        res.status(200).json({ message: 'Marked as read' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 5. إرسال رسالة مع إشعار FCM + WebSocket (POST /api/chats/:id/messages)
router.post('/:id/messages', async (req, res) => {
    try {
        const { text, senderId, recipientId } = req.body;
        const chatId = req.params.id;

        // 1. حفظ الرسالة في قاعدة البيانات
        await db.collection('chats').doc(chatId).collection('messages').add({
            text,
            senderId,
            recipientId,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // 2. تحديث معلومات آخر رسالة في المحادثة
        await db.collection('chats').doc(chatId).update({
            lastMessage: text,
            lastMessageTimestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        // 3. إرسال رسالة فورية عبر WebSocket
        if (req.sendToUser) {
            const socketMessage = {
                type: 'new_message',
                chatId: chatId,
                text: text,
                senderId: senderId,
                timestamp: new Date().toISOString()
            };

            req.sendToUser(recipientId, socketMessage);
            req.sendToUser(senderId, socketMessage);
        }

        // 4. إرسال إشعار FCM (للخلفية)
        const recipientDoc = await db.collection('users').doc(recipientId).get();
        const recipientToken = recipientDoc.data()?.fcmToken;
        const senderDoc = await db.collection('users').doc(senderId).get();
        const senderName = senderDoc.data()?.username || 'مستخدم';

        if (recipientToken) {
            try {
                await admin.messaging().send({
                    token: recipientToken,
                    notification: {
                        title: `رسالة من ${senderName}`,
                        body: text.substring(0, 50)
                    },
                    data: {
                        type: 'chat',
                        chatId: chatId,
                        recipientId: recipientId,
                        recipientName: senderName
                    }
                });
            } catch (notifError) {
                console.error('Error sending notification:', notifError);
            }
        }

        res.status(201).json({ message: 'Sent' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;