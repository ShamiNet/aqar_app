const express = require('express');
const router = express.Router();
const { db } = require('../firebaseConfig');
const admin = require('firebase-admin');
const { verifyToken } = require('../middleware/auth'); 

// 1. إضافة عقار جديد
router.post('/', verifyToken, async (req, res) => {
  try {
    const {
      title, price, description, address,
      latitude, longitude, category,
      propertyType,
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

    // ✅ تسجيل propertyType للتصحيح
    console.log('📝 Adding new property with type:', propertyType || 'بيت (default)');

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
      propertyType: propertyType || 'بيت',
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
    res.status(200).json({ success: true, message: 'Property updated successfully' });
  } catch (error) {
    console.error("Update Error:", error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ 3. نقطة نهاية جديدة لزيادة عدد المشاهدات
router.post('/:id/view', async (req, res) => {
    try {
        const propertyRef = db.collection('properties').doc(req.params.id);
        await propertyRef.update({
            views: admin.firestore.FieldValue.increment(1)
        });
        res.status(200).json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 4. جلب كل العقارات
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

// 5. جلب عقار واحد
router.get('/:id', async (req, res) => {
    try {
      const doc = await db.collection('properties').doc(req.params.id).get();
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
      res.status(200).json(data);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
});

// 6. حذف العقار
router.delete('/:id', verifyToken, async (req, res) => {
    try {
        const docRef = db.collection('properties').doc(req.params.id);
        const doc = await docRef.get();
        if (!doc.exists) return res.status(404).json({ error: 'Not found' });
        
        const userDoc = await db.collection('users').doc(req.userId).get();
        const isAdmin = userDoc.exists && userDoc.data().isAdmin === true;

        if (doc.data().ownerId !== req.userId && !isAdmin) {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        
        await docRef.delete();
        res.status(200).json({ message: 'Deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;