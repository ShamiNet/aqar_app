// routes/users.js
const express = require('express');
const router = express.Router();
const { db } = require('../firebaseConfig');
const admin = require('firebase-admin');
const { verifyToken } = require('../middleware/auth');

// ==================================================================
// 1. جلب بيانات مستخدم محدد (مع الإصلاح الذاتي للبيانات الناقصة)
// ==================================================================
router.get('/:id', async (req, res) => {
  try {
    const userId = req.params.id;
    const doc = await db.collection('users').doc(userId).get();

    if (!doc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }

    let data = doc.data();
    let updates = {};
    let needsUpdate = false;

    // 🛠️ إصلاح ذاتي: إذا كان تاريخ الانضمام مفقوداً
    if (!data.createdAt) {
        console.log(`🔧 Fixing missing createdAt for user: ${userId}`);

        // 1. تجهيز التحديث للداتابيز
        updates.createdAt = admin.firestore.FieldValue.serverTimestamp();

        // 2. تحديث المتغير المحلي ليرسله السيرفر في الرد فوراً (كي لا يظهر null في التطبيق)
        data.createdAt = { _seconds: Math.floor(Date.now() / 1000), _nanoseconds: 0 };

        needsUpdate = true;
    }

    // تنفيذ التحديث في الخلفية إذا لزم الأمر
    if (needsUpdate) {
        await db.collection('users').doc(userId).update(updates);
    }

    // ✅ تحويل Firestore Timestamps إلى format واضح للتطبيق
    const formatTimestamp = (timestamp) => {
      if (!timestamp) return null;
      if (timestamp._seconds !== undefined) {
        return {
          _seconds: timestamp._seconds,
          _nanoseconds: timestamp._nanoseconds || 0
        };
      }
      return timestamp;
    };

    const publicProfile = {
      id: doc.id,
      username: data.username || 'مستخدم',
      bio: data.bio || '',
      phone: data.phone || data.phoneNumber || '',
      phoneNumber: data.phoneNumber || data.phone || '',
      email: data.email || '', // إضافة الإيميل
      profileImageUrl: data.profileImageUrl,
      isVerified: data.isVerified || false,
      role: data.role || 'user',
      reputationScore: data.reputationScore || 0,
      reputationCount: data.reputationCount || 0,
      isBanned: data.isBanned || false,
      isAdmin: data.isAdmin || false,
      isOnline: data.isOnline || false,
      lastSeen: formatTimestamp(data.lastSeen),
      createdAt: formatTimestamp(data.createdAt), // ✅ تحويل التاريخ
      joinedAt: formatTimestamp(data.createdAt),  // ✅ احتياطي لتجنب المشاكل
      uid: doc.id,              // ✅ إضافة uid
      userId: doc.id            // ✅ إضافة userId
    };

    console.log(`✅ [USER-PROFILE] Fetched profile for user: ${userId}`, {
      hasUsername: !!publicProfile.username,
      hasEmail: !!publicProfile.email,
      hasPhone: !!publicProfile.phone,
      hasBio: !!publicProfile.bio,
      isVerified: publicProfile.isVerified,
      isAdmin: publicProfile.isAdmin,
      isBanned: publicProfile.isBanned,
      hasProfileImage: !!publicProfile.profileImageUrl,
      hasCreatedAt: !!publicProfile.createdAt,
      createdAtType: publicProfile.createdAt ? typeof publicProfile.createdAt : 'null',
      hasLastSeen: !!publicProfile.lastSeen,
    });

    res.status(200).json(publicProfile);
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==================================================================
// 2. تحديث الملف الشخصي
// ==================================================================
router.put('/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;

    // حماية: التأكد من أن المستخدم يحدث بياناته هو فقط
    if (req.userId !== id) {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    const updates = req.body;

    // منع تحديث حقول حساسة يدوياً
    delete updates.isAdmin;
    delete updates.isVerified;
    delete updates.reputationScore;

    await db.collection('users').doc(id).update(updates);

    res.status(200).json({ message: 'Profile updated successfully' });
  } catch (error) {
    console.error('Update Profile Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==================================================================
// 3. إضافة تقييم لمستخدم
// ==================================================================
router.post('/:id/reviews', verifyToken, async (req, res) => {
    try {
        const targetUserId = req.params.id;
        const { rating, comment } = req.body;
        const reviewerId = req.userId;

        if (targetUserId === reviewerId) {
            return res.status(400).json({ error: 'You cannot review yourself' });
        }

        const userRef = db.collection('users').doc(targetUserId);

        await db.runTransaction(async (t) => {
            const userDoc = await t.get(userRef);
            if (!userDoc.exists) throw "User not found";

            const data = userDoc.data();
            const currentScore = data.reputationScore || 0;
            const currentCount = data.reputationCount || 0;

            const newScore = ((currentScore * currentCount) + rating) / (currentCount + 1);
            const newCount = currentCount + 1;

            t.update(userRef, {
                reputationScore: newScore,
                reputationCount: newCount
            });

            const reviewRef = userRef.collection('reviews').doc();
            t.set(reviewRef, {
                rating,
                comment,
                reviewerId: reviewerId,
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            });
        });

        res.status(201).json({ message: 'Review added' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.message });
    }
});

// ==================================================================
// 4. جلب تقييمات مستخدم
// ==================================================================
router.get('/:id/reviews', async (req, res) => {
    try {
        const snapshot = await db.collection('users')
            .doc(req.params.id)
            .collection('reviews')
            .orderBy('timestamp', 'desc')
            .get();

        const reviews = [];
        snapshot.forEach(doc => reviews.push({ id: doc.id, ...doc.data() }));
        res.json(reviews);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==================================================================
// 5. حفظ FCM Token
// ==================================================================
router.post('/:userId/fcm', verifyToken, async (req, res) => {
    try {
        const { userId } = req.params;
        const { fcmToken } = req.body;

        if (req.userId !== userId) return res.status(403).json({ error: 'Unauthorized' });

        if (!fcmToken) {
            return res.status(400).json({ error: 'fcmToken is required' });
        }

        await db.collection('users').doc(userId).update({
            fcmToken: fcmToken,
            fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // console.log(`✅ FCM token updated for user: ${userId}`);
        res.json({ message: 'FCM token saved successfully' });
    } catch (error) {
        console.error('Error saving FCM token:', error);
        res.status(500).json({ error: error.message });
    }
});

// ==================================================================
// 6. تحديث حالة الاتصال (Online/Offline)
// ==================================================================
router.post('/:userId/online-status', verifyToken, async (req, res) => {
    try {
        const { userId } = req.params;
        const { isOnline } = req.body;

        if (req.userId !== userId) return res.status(403).json({ error: 'Unauthorized' });

        const updateData = {
            isOnline: isOnline,
            lastSeen: admin.firestore.FieldValue.serverTimestamp()
        };

        await db.collection('users').doc(userId).update(updateData);
        
        console.log(`🔄 [ONLINE-STATUS] User ${userId} status updated:`, {
          isOnline,
          timestamp: new Date().toISOString()
        });
        
        res.json({ message: 'Online status updated' });
    } catch (error) {
        console.error('Error updating online status:', error);
        res.status(500).json({ error: error.message });
    }
});

// ===== Favorites (public for logged-in users) =====

const canAccessUser = (req, targetUserId) =>
  req.userId === targetUserId || req.isSuperAdmin || (req.adminUser?.isAdmin ?? false);

// جلب المفضلة
router.get('/:id/favorites', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    if (!canAccessUser(req, id))
      return res.status(403).json({ message: 'صلاحيات غير كافية' });

    const favSnap = await db.collection('users').doc(id).collection('favorites').get();
    const propertyIds = favSnap.docs.map(d => d.id);
    if (!propertyIds.length) return res.json([]);

    const propDocs = await Promise.all(
      propertyIds.map(pid => db.collection('properties').doc(pid).get())
    );

    const result = propDocs
      .filter(d => d.exists)
      .map(d => ({ id: d.id, ...d.data() }));

    return res.json(result);
  } catch (e) {
    console.error('[Favorites][GET] error', e);
    return res.status(500).json({ message: 'فشل جلب المفضلة' });
  }
});

// إضافة إلى المفضلة
router.post('/:id/favorites', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { propertyId } = req.body || {};
    if (!propertyId) return res.status(400).json({ message: 'propertyId مطلوب' });
    if (!canAccessUser(req, id))
      return res.status(403).json({ message: 'صلاحيات غير كافية' });

    const propDoc = await db.collection('properties').doc(propertyId).get();
    if (!propDoc.exists)
      return res.status(404).json({ message: 'العقار غير موجود' });

    await db
      .collection('users')
      .doc(id)
      .collection('favorites')
      .doc(propertyId)
      .set({
        propertyId,
        createdAt: new Date().toISOString(),
      });

    return res.status(201).json({ message: 'تمت الإضافة للمفضلة' });
  } catch (e) {
    console.error('[Favorites][POST] error', e);
    return res.status(500).json({ message: 'فشل إضافة المفضلة' });
  }
});

// إزالة من المفضلة
router.delete('/:id/favorites/:propertyId', verifyToken, async (req, res) => {
  try {
    const { id, propertyId } = req.params;
    if (!canAccessUser(req, id))
      return res.status(403).json({ message: 'صلاحيات غير كافية' });

    await db
      .collection('users')
      .doc(id)
      .collection('favorites')
      .doc(propertyId)
      .delete();

    return res.status(204).send();
  } catch (e) {
    console.error('[Favorites][DELETE] error', e);
    return res.status(500).json({ message: 'فشل الحذف من المفضلة' });
  }
});

// ✅ جلب العقارات المشاهدة
router.get('/:id/viewed-properties', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { limit } = req.query;
    
    // ✅ التحقق من الصلاحيات (يجب أن يكون المستخدم نفسه أو أدمن)
    if (!canAccessUser(req, id))
      return res.status(403).json({ message: 'صلاحيات غير كافية' });
    
    console.log(`📊 [VIEWED-PROPERTIES] Fetching for user: ${id}`);
    
    // جلب قائمة العقارات المشاهدة
    let query = db
      .collection('users')
      .doc(id)
      .collection('viewedProperties')
      .orderBy('viewedAt', 'desc');
    
    if (limit) {
      query = query.limit(parseInt(limit));
    } else {
      query = query.limit(20); // افتراضياً 20 عقار
    }
    
    const viewedSnap = await query.get();
    const propertyIds = viewedSnap.docs.map(d => d.data().propertyId);
    
    if (!propertyIds.length) return res.json([]);

    // جلب تفاصيل العقارات
    const propDocs = await Promise.all(
      propertyIds.map(pid => db.collection('properties').doc(pid).get())
    );

    const result = propDocs
      .filter(d => d.exists)
      .map(d => ({ id: d.id, ...d.data() }));

    console.log(`✅ [VIEWED-PROPERTIES] Found ${result.length} properties for user ${id}`);
    return res.json(result);
  } catch (e) {
    console.error('[Viewed Properties][GET] error', e);
    return res.status(500).json({ message: 'فشل جلب العقارات المشاهدة' });
  }
});

module.exports = router;