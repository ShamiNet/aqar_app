// =====================================================
// كود الـ Admin Endpoints - للإضافة إلى ~/aqar-server/index.js
// =====================================================

// 1. أضف هذا الـ Middleware في بداية الملف (بعد تعريف router)

/**
 * Middleware للتحقق من أن المستخدم admin
 */
const adminOnly = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized - No token provided' });
    }

    const token = authHeader.split('Bearer ')[1];
    
    // ملاحظة: إذا كنت تستخدم token مؤقت بصيغة signup_${userId}
    // يجب تعديل هذا ليتحقق من النوع الصحيح
    if (token.startsWith('signup_')) {
      // استخراج userId من الـ token المؤقت
      const userId = token.replace('signup_', '');
      const userDoc = await db.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return res.status(404).json({ error: 'User not found' });
      }
      
      if (!userDoc.data()?.isAdmin) {
        return res.status(403).json({ error: 'Forbidden - Admin access required' });
      }
      
      req.userId = userId;
      return next();
    }

    // إذا كان token حقيقي من Firebase
    const decodedToken = await admin.auth().verifyIdToken(token);
    const userDoc = await db.collection('users').doc(decodedToken.uid).get();
    
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    if (!userDoc.data()?.isAdmin) {
      return res.status(403).json({ error: 'Forbidden - Admin access required' });
    }

    req.userId = decodedToken.uid;
    next();
  } catch (error) {
    console.error('Admin auth error:', error);
    res.status(401).json({ error: 'Invalid or expired token' });
  }
};

// =====================================================
// 2. أضف هذه الـ Endpoints (في قسم routes)
// =====================================================

/**
 * GET /api/admin/stats
 * جلب إحصائيات التطبيق
 */
router.get('/admin/stats', adminOnly, async (req, res) => {
  try {
    console.log('📊 Fetching admin stats...');
    
    const [usersSnap, propertiesSnap, chatsSnap] = await Promise.all([
      db.collection('users').get(),
      db.collection('properties').get(),
      db.collection('chats').get(),
    ]);
    
    const stats = {
      users: usersSnap.size,
      properties: propertiesSnap.size,
      chats: chatsSnap.size,
    };
    
    console.log('✅ Stats fetched successfully:', stats);
    res.json(stats);
  } catch (error) {
    console.error('❌ Error fetching admin stats:', error);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

/**
 * GET /api/admin/users
 * جلب جميع المستخدمين
 */
router.get('/admin/users', adminOnly, async (req, res) => {
  try {
    console.log('👥 Fetching all users...');
    
    const usersSnapshot = await db.collection('users').get();
    const users = [];
    
    usersSnapshot.forEach(doc => {
      const data = doc.data();
      users.push({
        id: doc.id,
        username: data.username || 'مستخدم',
        email: data.email || '',
        phone: data.phone || '',
        isBanned: data.isBanned || false,
        isAdmin: data.isAdmin || false,
        createdAt: data.createdAt || null,
        reputationScore: data.reputationScore || 0,
        reputationCount: data.reputationCount || 0,
      });
    });
    
    console.log(`✅ Fetched ${users.length} users`);
    res.json(users);
  } catch (error) {
    console.error('❌ Error fetching users:', error);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

/**
 * POST /api/admin/users/:userId/ban
 * حظر أو إلغاء حظر مستخدم
 */
router.post('/admin/users/:userId/ban', adminOnly, async (req, res) => {
  try {
    const { userId } = req.params;
    const { isBanned } = req.body;
    
    console.log(`🚫 ${isBanned ? 'Banning' : 'Unbanning'} user: ${userId}`);
    
    await db.collection('users').doc(userId).update({
      isBanned: isBanned === true,
    });
    
    console.log(`✅ User ${userId} ban status updated to: ${isBanned}`);
    res.json({ success: true, isBanned });
  } catch (error) {
    console.error('❌ Error updating user ban status:', error);
    res.status(500).json({ error: 'Failed to update user ban status' });
  }
});

/**
 * GET /api/admin/chats
 * جلب جميع المحادثات
 */
router.get('/admin/chats', adminOnly, async (req, res) => {
  try {
    console.log('💬 Fetching all chats...');
    
    const chatsSnapshot = await db.collection('chats').get();
    const chats = [];
    
    chatsSnapshot.forEach(doc => {
      const data = doc.data();
      chats.push({
        id: doc.id,
        participants: data.participants || [],
        lastMessage: data.lastMessage || '',
        lastMessageTime: data.lastMessageTime || null,
        createdAt: data.createdAt || null,
      });
    });
    
    console.log(`✅ Fetched ${chats.length} chats`);
    res.json(chats);
  } catch (error) {
    console.error('❌ Error fetching chats:', error);
    res.status(500).json({ error: 'Failed to fetch chats' });
  }
});

/**
 * GET /api/admin/reports
 * جلب جميع البلاغات
 */
router.get('/admin/reports', adminOnly, async (req, res) => {
  try {
    console.log('📝 Fetching all reports...');
    
    const reportsSnapshot = await db.collection('reports').get();
    const reports = [];
    
    reportsSnapshot.forEach(doc => {
      const data = doc.data();
      reports.push({
        id: doc.id,
        reason: data.reason || '',
        details: data.details || '',
        reportedBy: data.reportedBy || '',
        reportedUser: data.reportedUser || '',
        reportedProperty: data.reportedProperty || '',
        status: data.status || 'pending',
        createdAt: data.createdAt || null,
      });
    });
    
    console.log(`✅ Fetched ${reports.length} reports`);
    res.json(reports);
  } catch (error) {
    console.error('❌ Error fetching reports:', error);
    res.status(500).json({ error: 'Failed to fetch reports' });
  }
});

/**
 * GET /api/admin/app-settings
 * جلب إعدادات التطبيق
 */
router.get('/admin/app-settings', adminOnly, async (req, res) => {
  try {
    console.log('⚙️ Fetching app settings...');
    
    const settingsDoc = await db.collection('settings').doc('app').get();
    
    if (!settingsDoc.exists) {
      // إرجاع قيم افتراضية إذا لم توجد الإعدادات
      const defaultSettings = {
        min_version: '1.0.0',
        maintenance_mode: false,
        maintenance_message: '',
      };
      console.log('📝 No settings found, returning defaults');
      return res.json(defaultSettings);
    }
    
    const settings = settingsDoc.data();
    console.log('✅ Settings fetched successfully');
    res.json(settings);
  } catch (error) {
    console.error('❌ Error fetching app settings:', error);
    res.status(500).json({ error: 'Failed to fetch app settings' });
  }
});

/**
 * PUT /api/admin/app-settings
 * تحديث إعدادات التطبيق
 */
router.put('/admin/app-settings', adminOnly, async (req, res) => {
  try {
    console.log('⚙️ Updating app settings...');
    
    const { min_version, maintenance_mode, maintenance_message } = req.body;
    
    const settings = {
      min_version: min_version || '1.0.0',
      maintenance_mode: maintenance_mode || false,
      maintenance_message: maintenance_message || '',
    };
    
    await db.collection('settings').doc('app').set(settings, { merge: true });
    
    console.log('✅ Settings updated successfully:', settings);
    res.json({ success: true, settings });
  } catch (error) {
    console.error('❌ Error updating app settings:', error);
    res.status(500).json({ error: 'Failed to update app settings' });
  }
});

/**
 * POST /api/admin/users/:userId/admin
 * تعديل صلاحيات المشرف للمستخدم
 */
router.post('/admin/users/:userId/admin', adminOnly, async (req, res) => {
  try {
    const { userId } = req.params;
    const { isAdmin } = req.body;
    
    console.log(`👑 ${isAdmin ? 'Promoting' : 'Demoting'} user: ${userId}`);
    
    await db.collection('users').doc(userId).update({
      isAdmin: isAdmin === true,
    });
    
    console.log(`✅ User ${userId} admin status updated to: ${isAdmin}`);
    res.json({ success: true, isAdmin });
  } catch (error) {
    console.error('❌ Error updating user admin status:', error);
    res.status(500).json({ error: 'Failed to update user admin status' });
  }
});

// =====================================================
// ملاحظات مهمة:
// =====================================================
// 1. تأكد من أن لديك مستخدم واحد على الأقل بـ isAdmin: true
// 2. استخدم Firebase Console لتعيين isAdmin يدوياً لأول مرة
// 3. جميع الـ endpoints تتطلب Authorization header
// 4. التوكن يجب أن يكون بصيغة: "Bearer YOUR_TOKEN"
