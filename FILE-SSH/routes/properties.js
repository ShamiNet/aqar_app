const express = require('express');
const router = express.Router();
const { db } = require('../firebaseConfig');
const admin = require('firebase-admin');
const { verifyToken } = require('../middleware/auth'); // تأكد من وجود هذا الملف

// 1. إضافة عقار جديد
router.post('/', verifyToken, async (req, res) => {
  try {
    const {
      title, price, description, address,
      latitude, longitude, category,
      bedrooms, bathrooms, area, features,
      images, videoUrl,
      // الحقول الجديدة
      livingRooms, streetWidth, age,
      isFurnished, hasKitchen, hasAnnex, hasCarEntrance, hasElevator, hasPool
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
      // الحقول الجديدة
      livingRooms: parseInt(livingRooms) || 0,
      streetWidth: parseFloat(streetWidth) || 0,
      age: parseInt(age) || 0,
      // الخيارات
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
      views: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection('properties').add(newProperty);
    res.status(201).json({ success: true, message: 'Added successfully', propertyId: docRef.id });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 2. تعديل عقار (هذا هو الجزء الذي كان ناقصاً ويسبب المشكلة)
router.put('/:id', verifyToken, async (req, res) => {
  try {
    const propertyId = req.params.id;
    const propertyRef = db.collection('properties').doc(propertyId);
    const doc = await propertyRef.get();

    if (!doc.exists) {
      return res.status(404).json({ error: 'Property not found' });
    }

    // التحقق من أن المستخدم هو صاحب العقار
    if (doc.data().ownerId !== req.userId) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const updates = { ...req.body };

    // تحويل الأرقام إذا تم إرسالها كسلاسل نصية
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
    
    // معالجة الحقول الجديدة في التحديث
    if (updates.livingRooms) updates.livingRooms = parseInt(updates.livingRooms);
    if (updates.streetWidth) updates.streetWidth = parseFloat(updates.streetWidth);
    if (updates.age) updates.age = parseInt(updates.age);

    // تنظيف البيانات (إزالة الحقول التي لا يجب تحديثها)
    delete updates.id;
    delete updates.ownerId;
    delete updates.createdAt;
    
    updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();

    await propertyRef.update(updates);
    res.status(200).json({ success: true, message: 'Property updated successfully' });
  } catch (error) {
    console.error("Update Error:", error);
    res.status(500).json({ error: error.message });
  }
});

// 3. جلب كل العقارات
router.get('/', async (req, res) => {
  try {
    const { userId } = req.query;
    let query = db.collection('properties');
    if (userId) query = query.where('ownerId', '==', userId);

    const snapshot = await query.get();
    let properties = snapshot.docs.map(doc => {
        const data = doc.data();
        if (data.location) {
            data.latitude = data.location._latitude;
            data.longitude = data.location._longitude;
        }
        return { id: doc.id, ...data };
    });
    // ترتيب تنازلي حسب التاريخ
    properties.sort((a, b) => {
       const tA = a.createdAt && a.createdAt.toDate ? a.createdAt.toDate().getTime() : 0;
       const tB = b.createdAt && b.createdAt.toDate ? b.createdAt.toDate().getTime() : 0;
       return tB - tA;
    });

    res.status(200).json(properties);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 4. جلب عقار واحد
router.get('/:id', async (req, res) => {
    try {
      const doc = await db.collection('properties').doc(req.params.id).get();
      if (!doc.exists) return res.status(404).json({ message: 'Not found' });
      let data = { id: doc.id, ...doc.data() };
      
      if (data.location) {
        data.latitude = data.location._latitude;
        data.longitude = data.location._longitude;
      }
      
      // جلب بيانات المعلن
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
      res.status(200).json(data);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
});

// 5. حذف العقار
router.delete('/:id', verifyToken, async (req, res) => {
    try {
        const docRef = db.collection('properties').doc(req.params.id);
        const doc = await docRef.get();
        if (!doc.exists) return res.status(404).json({ error: 'Not found' });
        
        // التحقق من الملكية أو إذا كان أدمن
        if (doc.data().ownerId !== req.userId && req.userRole !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        
        await docRef.delete();
        res.status(200).json({ message: 'Deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;