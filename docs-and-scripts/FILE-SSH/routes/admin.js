const express = require('express');
const router = express.Router();
const { db } = require('../firebaseConfig');
const { verifyToken } = require('../middleware/auth');

// 🛡️ Middleware: التحقق من أن المستخدم أدمن
const checkAdmin = async (req, res, next) => {
  try {
    const userId = req.userId;
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists || !userDoc.data().isAdmin) {
      return res.status(403).json({ error: 'غير مصرح: صلاحيات أدمن مطلوبة' });
    }
    next();
  } catch (error) {
    res.status(500).json({ error: 'حدث خطأ أثناء التحقق من الصلاحيات' });
  }
};

// ==========================================
// 1. 📊 إحصائيات النظام
// ==========================================
router.get('/stats', verifyToken, checkAdmin, async (req, res) => {
  try {
    const usersSnap = await db.collection('users').get();
    const propertiesSnap = await db.collection('properties').get();
    const chatsSnap = await db.collection('chats').get();
    const reportsSnap = await db.collection('reports').get();

    const stats = {
      users: usersSnap.size,
      properties: propertiesSnap.size,
      chats: chatsSnap.size,
      reports: reportsSnap.size,
      revenue: 0
    };
    res.status(200).json(stats);
  } catch (error) {
    res.status(500).json({ error: 'فشل جلب الإحصائيات' });
  }
});

// ==========================================
// 2. 👥 إدارة المستخدمين
// ==========================================
router.get('/users', verifyToken, checkAdmin, async (req, res) => {
  try {
    const { limit, search } = req.query;
    let query = db.collection('users');

    if (search) {
        query = query.where('username', '>=', search).where('username', '<=', search + '\uf8ff');
    }

    const snapshot = await query.limit(parseInt(limit) || 20).get();
    const users = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.status(200).json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/users/:id/ban', verifyToken, checkAdmin, async (req, res) => {
  try {
    const { isBanned } = req.body;
    await db.collection('users').doc(req.params.id).update({ isBanned });
    res.status(200).json({ message: 'Updated ban status' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/users/:id/verify', verifyToken, checkAdmin, async (req, res) => {
  try {
    const { isVerified } = req.body;
    await db.collection('users').doc(req.params.id).update({ isVerified });
    res.status(200).json({ message: 'Updated verification status' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/users/:id/admin', verifyToken, checkAdmin, async (req, res) => {
    try {
      const { isAdmin } = req.body;
      await db.collection('users').doc(req.params.id).update({ isAdmin });
      res.status(200).json({ message: 'Updated admin status' });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
});

// ==========================================
// 3. 💬 إدارة المحادثات (تم التحديث والإصلاح) 🛠️
// ==========================================

// جلب قائمة المحادثات
router.get('/chats', verifyToken, checkAdmin, async (req, res) => {
  try {
    const snapshot = await db.collection('chats').orderBy('createdAt', 'desc').limit(50).get();

    const chats = await Promise.all(snapshot.docs.map(async doc => {
      const data = doc.data();
      let participantNames = [];
      if (data.participants && data.participants.length > 0) {
        for (const uid of data.participants) {
            const uDoc = await db.collection('users').doc(uid).get();
            if (uDoc.exists) participantNames.push(uDoc.data().username || 'مجهول');
        }
      }
      return { id: doc.id, ...data, participantNames };
    }));

    res.status(200).json(chats);
  } catch (error) {
    res.status(500).json({ error: 'فشل جلب المحادثات' });
  }
});

// ✅ هذا هو الجزء الجديد والمهم: جلب تفاصيل ورسائل محادثة معينة للأدمن
router.get('/chats/:id/messages', verifyToken, checkAdmin, async (req, res) => {
  try {
    const chatId = req.params.id;

    // 1. جلب بيانات المحادثة الأساسية
    const chatDoc = await db.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) {
      return res.status(404).json({ error: 'المحادثة غير موجودة' });
    }
    const chatData = chatDoc.data();

    // 2. جلب بيانات المشاركين (للعرض في الواجهة)
    let participants = [];
    if (chatData.participants && Array.isArray(chatData.participants)) {
      for (const uid of chatData.participants) {
        const uDoc = await db.collection('users').doc(uid).get();
        if (uDoc.exists) {
          const uData = uDoc.data();
          participants.push({
            id: uDoc.id,
            username: uData.username || 'مجهول',
            email: uData.email,
            profileImage: uData.profileImageUrl,
            isOnline: uData.isOnline,
            isBanned: uData.isBanned
          });
        }
      }
    }

    // 3. جلب الرسائل
    const messagesSnap = await db.collection('chats').doc(chatId)
      .collection('messages')
      .orderBy('createdAt', 'asc')
      .get();

    const messages = messagesSnap.docs.map(doc => {
      const msgData = doc.data();
      // محاولة العثور على اسم المرسل من قائمة المشاركين
      const senderInfo = participants.find(p => p.id === msgData.senderId);

      // تحويل التوقيت إلى نص ISO لضمان عمله في Flutter
      let timestamp = msgData.createdAt;
      if (timestamp && timestamp.toDate) {
          timestamp = timestamp.toDate().toISOString();
      }

      return {
        id: doc.id,
        ...msgData,
        senderName: senderInfo ? senderInfo.username : 'مجهول',
        timestamp: timestamp
      };
    });

    // إرجاع البنية التي يتوقعها التطبيق
    res.status(200).json({
      chatId: chatId,
      ...chatData,
      participants: participants,
      messages: messages,
      totalMessages: messages.length
    });

  } catch (error) {
    console.error('Error fetching admin chat details:', error);
    res.status(500).json({ error: error.message });
  }
});

// حذف محادثة
router.delete('/chats/:id', verifyToken, checkAdmin, async (req, res) => {
    try {
        await db.collection('chats').doc(req.params.id).delete();
        // (اختياري) يمكنك حذف الرسائل الفرعية أيضاً هنا
        res.status(200).json({ message: 'Deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// 4. 🚨 إدارة البلاغات
// ==========================================
router.get('/reports', verifyToken, checkAdmin, async (req, res) => {
  try {
    const snapshot = await db.collection('reports').orderBy('createdAt', 'desc').get();
    const reports = await Promise.all(snapshot.docs.map(async doc => {
        const data = doc.data();
        let reporterName = 'غير معروف';
        if (data.reporterId) {
            const u = await db.collection('users').doc(data.reporterId).get();
            if (u.exists) reporterName = u.data().username;
        }
        return { id: doc.id, ...data, reporterName };
    }));
    res.status(200).json(reports);
  } catch (error) {
    res.status(500).json({ error: 'فشل جلب البلاغات' });
  }
});

router.put('/reports/:id', verifyToken, checkAdmin, async (req, res) => {
    try {
        const { status } = req.body;
        await db.collection('reports').doc(req.params.id).update({
            status,
            updatedAt: new Date()
        });
        res.status(200).json({ message: 'Report status updated' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

router.delete('/reports/:id', verifyToken, checkAdmin, async (req, res) => {
    try {
        await db.collection('reports').doc(req.params.id).delete();
        res.status(200).json({ message: 'Report deleted' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ========================================
// ==========================================
// 5. ⚙️ إعدادات التطبيق
// ==========================================
router.get('/settings/public', async (req, res) => {
  try {
    const doc = await db.collection('settings').doc('app').get();
    res.status(200).json(doc.exists ? doc.data() : {});
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/settings', verifyToken, checkAdmin, async (req, res) => {
  try {
    const rawText = (req.body.announcement_text ?? '').toString().trim();
    const rawUrl = (req.body.announcement_url ?? '').toString().trim();
    const rawEnabled = req.body.announcement_enabled === true;

    const announcement_text = rawText.length > 300 ? rawText.slice(0, 300) : rawText;
    const announcement_url =
      rawUrl && /^https?:\/\//i.test(rawUrl) ? rawUrl : '';

    // إذا تغيّر النص أو تم التفعيل، نولّد ID جديد
    let announcement_id = req.body.announcement_id;
    if (!announcement_id && rawEnabled && announcement_text) {
      announcement_id = `ann_${Date.now()}`;
    }

    const settingsPayload = {
      ...req.body,
      announcement_enabled: rawEnabled,
      announcement_text,
      announcement_url,
      announcement_id: announcement_id || null,
      announcement_updatedAt: new Date()
    };

    await db.collection('settings').doc('app').set(settingsPayload, { merge: true });
    res.status(200).json({ message: 'Settings updated' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});


// ✅ جلب العقارات أو الإعلانات المشاهدة (تم الإصلاح لتجنب أخطاء الفهارس المركبة)
router.get('/announcement-views', verifyToken, checkAdmin, async (req, res) => {
  try {
    const { announcementId, limit } = req.query;
    if (!announcementId) {
      return res.status(400).json({ error: 'announcementId مطلوب' });
    }

    // 1. جلب البيانات باستعلام بسيط جداً لا يحتاج إلى (Composite Index)
    const snap = await db.collection('announcement_views')
      .where('announcementId', '==', announcementId)
      .get();

    let viewsData = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    // 2. الترتيب تنازلياً برمجياً (من الأحدث للأقدم) داخل سيرفر Node.js
    viewsData.sort((a, b) => {
      const timeA = a.viewedAt ? (a.viewedAt.toDate ? a.viewedAt.toDate().getTime() : new Date(a.viewedAt).getTime()) : 0;
      const timeB = b.viewedAt ? (b.viewedAt.toDate ? b.viewedAt.toDate().getTime() : new Date(b.viewedAt).getTime()) : 0;
      return timeB - timeA;
    });

    // 3. تطبيق الحد الأقصى (Limit)
    const limitNum = parseInt(limit) || 50;
    viewsData = viewsData.slice(0, limitNum);

    // 4. دمج بيانات المستخدمين (الاسم والإيميل) وتنسيق الوقت
    const views = await Promise.all(viewsData.map(async (data) => {
      const userDoc = await db.collection('users').doc(data.userId).get();
      const user = userDoc.exists ? userDoc.data() : null;

      // ✅ تحويل التوقيت لنص مقروء (ISO) لكي لا يتعطل تطبيق فلاتر
      let timestamp = data.viewedAt;
      if (timestamp && timestamp.toDate) {
        timestamp = timestamp.toDate().toISOString();
      }

      return {
        ...data,
        username: user?.username || 'مجهول',
        email: user?.email || '',
        viewedAt: timestamp // إرسال الوقت منسقاً
      };
    }));

    res.status(200).json(views);
  } catch (error) {
    console.error('❌ Error fetching views:', error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ حذف جميع مشاهدات إعلان معين (يجب أن يأتي أولاً - أكثر تحديداً)
router.delete('/announcement-views/bulk/all', verifyToken, checkAdmin, async (req, res) => {
  try {
    const { announcementId } = req.query;

    if (!announcementId) {
      return res.status(400).json({ error: 'announcementId مطلوب' });
    }

    // جلب جميع المشاهدات لهذا الإعلان
    const snap = await db.collection('announcement_views')
      .where('announcementId', '==', announcementId)
      .get();

    const batch = db.batch();
    let deletedCount = 0;

    snap.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletedCount++;
    });

    await batch.commit();

    console.log(`✅ [DELETE-ALL-VIEWS] تم حذف ${deletedCount} مشاهدة للإعلان: ${announcementId}`);
    res.status(200).json({ 
      message: `تم حذف ${deletedCount} مشاهدة بنجاح`,
      deletedCount 
    });
  } catch (error) {
    console.error('❌ Error deleting all views:', error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ حذف مشاهدات مستخدم معين من إعلان معين (يأتي ثانياً)
router.delete('/announcement-views/user/:userId', verifyToken, checkAdmin, async (req, res) => {
  try {
    const { userId } = req.params;
    const { announcementId } = req.query;

    if (!userId || !announcementId) {
      return res.status(400).json({ error: 'userId و announcementId مطلوبان' });
    }

    // جلب المشاهدات المطابقة
    const snap = await db.collection('announcement_views')
      .where('announcementId', '==', announcementId)
      .where('userId', '==', userId)
      .get();

    const batch = db.batch();
    let deletedCount = 0;

    snap.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletedCount++;
    });

    await batch.commit();

    console.log(`✅ [DELETE-USER-VIEWS] تم حذف ${deletedCount} مشاهدة للمستخدم ${userId} من الإعلان ${announcementId}`);
    res.status(200).json({ 
      message: `تم حذف مشاهدات المستخدم بنجاح`,
      deletedCount 
    });
  } catch (error) {
    console.error('❌ Error deleting user views:', error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ حذف مشاهدة واحدة لمستخدم معين من الإعلان (يأتي أخيراً - الأقل تحديداً)
router.delete('/announcement-views/:viewId', verifyToken, checkAdmin, async (req, res) => {
  try {
    const { viewId } = req.params;

    if (!viewId) {
      return res.status(400).json({ error: 'viewId مطلوب' });
    }

    await db.collection('announcement_views').doc(viewId).delete();

    console.log(`✅ [DELETE-VIEW] تم حذف المشاهدة: ${viewId}`);
    res.status(200).json({ message: 'تم حذف المشاهدة بنجاح' });
  } catch (error) {
    console.error('❌ Error deleting view:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;