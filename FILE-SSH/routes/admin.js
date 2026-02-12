const express = require('express');
const router = express.Router();
const { db } = require('../firebaseConfig');
const { verifyToken } = require('../middleware/auth'); // تأكد من المسار

// 🛡️ Middleware: التحقق من أن المستخدم أدمن
const checkAdmin = async (req, res, next) => {
  try {
    const userId = req.userId; // القادم من verifyToken
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
// 1. 📊 إحصائيات النظام (Stats)
// ==========================================
router.get('/stats', verifyToken, checkAdmin, async (req, res) => {
  try {
    // جلب الأحجام (عدد الوثائق)
    // ملاحظة: count() هي الطريقة الأسرع والأحدث في Firestore،
    // ولكن إذا لم تعمل نسختك، سنستخدم get().size

    const usersSnap = await db.collection('users').get();
    const propertiesSnap = await db.collection('properties').get();
    const chatsSnap = await db.collection('chats').get();
    const reportsSnap = await db.collection('reports').get();

    const stats = {
      users: usersSnap.size,
      properties: propertiesSnap.size,
      chats: chatsSnap.size,
      reports: reportsSnap.size,
      revenue: 0 // يمكن حسابها لاحقاً من جدول المدفوعات
    };

    res.status(200).json(stats);
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({ error: 'فشل جلب الإحصائيات' });
  }
});

// ==========================================
// 2. 👥 إدارة المستخدمين (موجود وتعمل لديك)
// ==========================================
router.get('/users', verifyToken, checkAdmin, async (req, res) => {
  try {
    const { limit, search } = req.query;
    let query = db.collection('users');

    // بحث بسيط (اختياري)
    if (search) {
        // Firestore لا يدعم البحث النصي الكامل (Full Text) مباشرة بشكل جيد،
        // هذا مجرد مثال بسيط
        query = query.where('username', '>=', search).where('username', '<=', search + '\uf8ff');
    }

    const snapshot = await query.limit(parseInt(limit) || 20).get();
    const users = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.status(200).json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// حظر/فك حظر المستخدم
router.post('/users/:id/ban', verifyToken, checkAdmin, async (req, res) => {
  try {
    const { isBanned } = req.body;
    await db.collection('users').doc(req.params.id).update({ isBanned });
    res.status(200).json({ message: 'تم تحديث حالة الحظر' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// توثيق المستخدم
router.post('/users/:id/verify', verifyToken, checkAdmin, async (req, res) => {
  try {
    const { isVerified } = req.body;
    await db.collection('users').doc(req.params.id).update({ isVerified });
    res.status(200).json({ message: 'تم تحديث حالة التوثيق' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ترقية المستخدم لأدمن
router.post('/users/:id/admin', verifyToken, checkAdmin, async (req, res) => {
    try {
      const { isAdmin } = req.body;
      await db.collection('users').doc(req.params.id).update({ isAdmin });
      res.status(200).json({ message: 'تم تحديث صلاحيات الأدمن' });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

// ==========================================
// 3. 💬 إدارة المحادثات (Chats)
// ==========================================
router.get('/chats', verifyToken, checkAdmin, async (req, res) => {
  try {
    const snapshot = await db.collection('chats').orderBy('createdAt', 'desc').limit(50).get();

    const chats = await Promise.all(snapshot.docs.map(async doc => {
      const data = doc.data();

      // جلب أسماء المشاركين للعرض
      let participantNames = [];
      if (data.participants && data.participants.length > 0) {
        for (const uid of data.participants) {
            const uDoc = await db.collection('users').doc(uid).get();
            if (uDoc.exists) participantNames.push(uDoc.data().username || 'مجهول');
        }
      }

      return {
        id: doc.id,
        ...data,
        participantNames: participantNames
      };
    }));

    res.status(200).json(chats);
  } catch (error) {
    console.error('Error fetching chats:', error);
    res.status(500).json({ error: 'فشل جلب المحادثات' });
  }
});

// حذف محادثة
router.delete('/chats/:id', verifyToken, checkAdmin, async (req, res) => {
    try {
        await db.collection('chats').doc(req.params.id).delete();
        res.status(200).json({ message: 'Deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// 4. 🚨 إدارة البلاغات (Reports)
// ==========================================
router.get('/reports', verifyToken, checkAdmin, async (req, res) => {
  try {
    const snapshot = await db.collection('reports').orderBy('createdAt', 'desc').get();

    // تحسين البيانات: جلب اسم المُبلغ والمُبلغ عنه
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
    console.error('Error fetching reports:', error);
    res.status(500).json({ error: 'فشل جلب البلاغات' });
  }
});

// تحديث حالة البلاغ (قيد المراجعة / تم الحل)
router.put('/reports/:id', verifyToken, checkAdmin, async (req, res) => {
    try {
        const { status } = req.body; // 'pending', 'resolved', 'dismissed'
        await db.collection('reports').doc(req.params.id).update({
            status,
            updatedAt: new Date()
        });
        res.status(200).json({ message: 'Report status updated' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// حذف بلاغ
router.delete('/reports/:id', verifyToken, checkAdmin, async (req, res) => {
    try {
        await db.collection('reports').doc(req.params.id).delete();
        res.status(200).json({ message: 'Report deleted' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// 5. ⚙️ إعدادات التطبيق العامة
// ==========================================
router.get('/settings/public', async (req, res) => {
    // هذا المسار عام ولا يحتاج توكن
    try {
        const doc = await db.collection('settings').doc('app').get();
        res.status(200).json(doc.exists ? doc.data() : {});
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

router.post('/settings', verifyToken, checkAdmin, async (req, res) => {
    try {
        await db.collection('settings').doc('app').set(req.body, { merge: true });
        res.status(200).json({ message: 'Settings updated' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;