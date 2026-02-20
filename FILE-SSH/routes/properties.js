const express = require('express');
const router = express.Router();
const { db } = require('../firebaseConfig');
const admin = require('firebase-admin');
const { verifyToken } = require('../middleware/auth');

// ✅ دالة مساعدة لتنظيف الكاش عند إضافة/تعديل/حذف عقار
const clearPropertiesCache = async (redisClient, userId = null, propertyId = null) => {
    if (!redisClient) return;
    try {
        await redisClient.del('cache:properties:all'); // مسح الكاش العام
        if (userId) {
            await redisClient.del(`cache:properties:user:${userId}`); // مسح كاش المستخدم الخاص
        }
        if (propertyId) {
            await redisClient.del(`cache:property:${propertyId}`); // مسح كاش العقار المحدد
        }
        console.log('🧹 [Redis] تم تنظيف الكاش بنجاح لتحديث البيانات');
    } catch (err) {
        console.error('❌ [Redis] خطأ في تنظيف الكاش:', err);
    }
};

// 1. إضافة عقار جديد
router.post('/', verifyToken, async (req, res) => {
  try {
    const {
      title, price, description, address,
      latitude, longitude, category,
      bedrooms, bathrooms, area, features,
      images, videoUrl,
      livingRooms, streetWidth, age,
      isFurnished, hasKitchen, hasAnnex, hasCarEntrance, hasElevator, hasPool, isFeatured
    } = req.body;

    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);
    let locationData = null;
    if (!isNaN(lat) && !isNaN(lng)) {
        locationData = new admin.firestore.GeoPoint(lat, lng);
    }

    const newProperty = {
      ownerId: req.userId,
      title,
      price: parseFloat(price) || 0,
      description,
      address,
      location: locationData,
      latitude: lat,
      longitude: lng,
      category,
      bedrooms: parseInt(bedrooms) || 0,
      bathrooms: parseInt(bathrooms) || 0,
      area: parseFloat(area) || 0,
      livingRooms: parseInt(livingRooms) || 0,
      streetWidth: parseFloat(streetWidth) || 0,
      age: parseInt(age) || 0,

      isFeatured: isFeatured === true || isFeatured === 'true',
      isFurnished: isFurnished === true || isFurnished === 'true',
      hasKitchen: hasKitchen === true || hasKitchen === 'true',
      hasAnnex: hasAnnex === true || hasAnnex === 'true',
      hasCarEntrance: hasCarEntrance === true || hasCarEntrance === 'true',
      hasElevator: hasElevator === true || hasElevator === 'true',
      hasPool: hasPool === true || hasPool === 'true',

      features: (typeof features === 'string') ? JSON.parse(features) : (features || []),
      images: images || [],
      videoUrl: videoUrl || null,
      isVerified: false,
      isPaused: false,
      views: 0, // ✅ عداد المشاهدات
      isEdited: false, // ✅ حالة التعديل
      editHistory: [], // ✅ سجل التعديلات
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection('properties').add(newProperty);
    
    // ✅ مسح الكاش لأن هناك عقار جديد تمت إضافته
    await clearPropertiesCache(req.redisClient, req.userId);

    res.status(201).json({ success: true, message: 'Added successfully', propertyId: docRef.id });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 2. تعديل عقار (مع دعم الأدمن وسجل التعديلات) ✅
router.put('/:id', verifyToken, async (req, res) => {
  try {
    const propertyId = req.params.id;
    const propertyRef = db.collection('properties').doc(propertyId);
    const doc = await propertyRef.get();

    if (!doc.exists) {
      return res.status(404).json({ error: 'Property not found' });
    }

    // ✅ التحقق من صلاحيات المستخدم (هل هو صاحب العقار أم أدمن؟)
    const userDoc = await db.collection('users').doc(req.userId).get();
    const isAdmin = userDoc.exists && userDoc.data().isAdmin === true;
    const editorName = userDoc.exists ? userDoc.data().username : 'مجهول';

    if (doc.data().ownerId !== req.userId && !isAdmin) {
      return res.status(403).json({ error: 'Unauthorized: You are not the owner or admin' });
    }

    const updates = { ...req.body };

    if (updates.price) updates.price = parseFloat(updates.price);
    if (updates.bedrooms) updates.bedrooms = parseInt(updates.bedrooms);
    if (updates.bathrooms) updates.bathrooms = parseInt(updates.bathrooms);
    if (updates.area) updates.area = parseFloat(updates.area);
    if (updates.latitude && updates.longitude) {
        updates.location = new admin.firestore.GeoPoint(
            parseFloat(updates.latitude),
            parseFloat(updates.longitude)
        );
    }

    if (updates.livingRooms) updates.livingRooms = parseInt(updates.livingRooms);
    if (updates.streetWidth) updates.streetWidth = parseFloat(updates.streetWidth);
    if (updates.age) updates.age = parseInt(updates.age);

    if (updates.isFeatured !== undefined) {
      updates.isFeatured = updates.isFeatured === true || updates.isFeatured === 'true';
    }

    delete updates.id;
    delete updates.ownerId;
    delete updates.createdAt;

    // ✅ تسجيل بيانات التعديل
    const editEntry = {
        editorName: editorName,
        role: isAdmin ? 'إدارة التطبيق' : 'صاحب العقار',
        timestamp: new Date().toISOString() // حفظ الوقت بدقة
    };

    updates.isEdited = true;
    updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    updates.editHistory = admin.firestore.FieldValue.arrayUnion(editEntry);

    await propertyRef.update(updates);
    
    // ✅ مسح الكاش ليتحدث العرض لدى جميع المستخدمين
    await clearPropertiesCache(req.redisClient, doc.data().ownerId, propertyId);

    res.status(200).json({ success: true, message: 'Property updated successfully' });
  } catch (error) {
    console.error("Update Error:", error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ 3. نقطة نهاية لزيادة عدد المشاهدات وتتبع المستخدمين
router.post('/:id/view', async (req, res) => {
    try {
        const propertyId = req.params.id;
        const { userId } = req.body; // ✅ استقبال userId من التطبيق
        
        const propertyRef = db.collection('properties').doc(propertyId);
        await propertyRef.update({
            views: admin.firestore.FieldValue.increment(1)
        });
        
        // ✅ حفظ العقار في قائمة المشاهدات للمستخدم (إذا كان مسجل دخول)
        if (userId) {
            try {
                await db
                    .collection('users')
                    .doc(userId)
                    .collection('viewedProperties')
                    .doc(propertyId)
                    .set({
                        propertyId: propertyId,
                        viewedAt: admin.firestore.FieldValue.serverTimestamp()
                    }, { merge: true }); // merge للتحديث إذا كان موجود
                
                console.log(`✅ [VIEW-TRACKING] User ${userId} viewed property ${propertyId}`);
            } catch (trackError) {
                console.error('⚠️ Error tracking view:', trackError);
                // نستمر حتى لو فشل التتبع
            }
        }
        
        // ✅ مسح كاش العقار المحدد فقط لتحديث عدد المشاهدات
        if (req.redisClient) {
            await req.redisClient.del(`cache:property:${propertyId}`);
        }

        res.status(200).json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 4. جلب كل العقارات (مع تفعيل Redis) ✅
// 4. جلب كل العقارات (مع تفعيل Redis والـ Pagination) ✅
router.get('/', async (req, res) => {
  try {
    const { userId, page, limit } = req.query;
    const pageNum = parseInt(page) || 1;
    const limitNum = parseInt(limit) || 50; 
    
    const cacheKey = userId ? `cache:properties:user:${userId}` : 'cache:properties:all';
    let properties = [];

    // ✅ 1. البحث في Redis أولاً
    if (req.redisClient) {
        const cachedProperties = await req.redisClient.get(cacheKey);
        if (cachedProperties) {
            properties = JSON.parse(cachedProperties);
        }
    }

    // ✅ 2. إذا لم يكن في الكاش، نجلبه من قاعدة البيانات
    if (properties.length === 0) {
        let query = db.collection('properties');
        if (userId) query = query.where('ownerId', '==', userId);

        const snapshot = await query.get();
        properties = snapshot.docs.map(doc => {
            const data = doc.data();
            if (data.location) {
                data.latitude = data.location._latitude;
                data.longitude = data.location._longitude;
            }
            return { id: doc.id, ...data };
        });

        properties.sort((a, b) => {
           const tA = a.createdAt && a.createdAt.toDate ? a.createdAt.toDate().getTime() : 0;
           const tB = b.createdAt && b.createdAt.toDate ? b.createdAt.toDate().getTime() : 0;
           return tB - tA;
        });

        // تخزين النتيجة الكاملة في Redis لمدة ساعة
        if (req.redisClient) {
            await req.redisClient.setEx(cacheKey, 3600, JSON.stringify(properties));
        }
    }

    // ✅ 3. تطبيق نظام الـ Pagination (تقطيع المصفوفة)
    const startIndex = (pageNum - 1) * limitNum;
    const endIndex = pageNum * limitNum;
    const paginatedProperties = properties.slice(startIndex, endIndex);

    // إرسال البيانات المقطعة فقط للهاتف لعدم تجميد التطبيق
    res.status(200).json(paginatedProperties);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 5. جلب عقار واحد (مع تفعيل Redis) ✅
router.get('/:id', async (req, res) => {
    try {
      const propertyId = req.params.id;
      const cacheKey = `cache:property:${propertyId}`;

      // ✅ 1. التحقق من الكاش
      if (req.redisClient) {
          const cachedProperty = await req.redisClient.get(cacheKey);
          if (cachedProperty) {
              console.log(`⚡ [Redis] جلب العقار المباشر من التخزين المؤقت`);
              return res.status(200).json(JSON.parse(cachedProperty));
          }
      }

      console.log(`⏳ [MongoDB/Firestore] جلب العقار من قاعدة البيانات...`);
      const doc = await db.collection('properties').doc(propertyId).get();
      if (!doc.exists) return res.status(404).json({ message: 'Not found' });
      let data = { id: doc.id, ...doc.data() };

      if (data.location) {
        data.latitude = data.location._latitude;
        data.longitude = data.location._longitude;
      }

      if (data.ownerId) {
         const userDoc = await db.collection('users').doc(data.ownerId).get();
         if (userDoc.exists) {
            const u = userDoc.data();
            data.sellerInfo = {
               username: u.username,
               email: u.email,
               phone: u.phone,
               profileImageUrl: u.profileImageUrl,
               isVerified: u.isVerified,
               role: u.role
            };
         }
      }

      // ✅ 2. حفظ البيانات في Redis لمدة ساعة
      if (req.redisClient) {
          await req.redisClient.setEx(cacheKey, 3600, JSON.stringify(data));
      }

      res.status(200).json(data);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
});

// 6. حذف العقار
router.delete('/:id', verifyToken, async (req, res) => {
    try {
        const propertyId = req.params.id;
        const docRef = db.collection('properties').doc(propertyId);
        const doc = await docRef.get();
        if (!doc.exists) return res.status(404).json({ error: 'Not found' });

        const userDoc = await db.collection('users').doc(req.userId).get();
        const isAdmin = userDoc.exists && userDoc.data().isAdmin === true;

        if (doc.data().ownerId !== req.userId && !isAdmin) {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        
        const ownerId = doc.data().ownerId;
        await docRef.delete();

        // ✅ مسح الكاش لإزالة العقار المحذوف من قوائم المستخدمين
        await clearPropertiesCache(req.redisClient, ownerId, propertyId);

        res.status(200).json({ message: 'Deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;