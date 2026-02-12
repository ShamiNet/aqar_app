const express = require('express');
const router = express.Router();
const { db } = require('../firebaseConfig');
const admin = require('firebase-admin');

// إرسال طلب صفقة جديد
router.post('/', async (req, res) => {
    try {
        const dealData = {
            ...req.body,
            status: 'pending',
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        };
        const doc = await db.collection('deals').add(dealData);
        res.status(201).json({ id: doc.id });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// جلب الصفقات
router.get('/', async (req, res) => {
    try {
        const { userId, role } = req.query;
        // role إما 'buyerId' أو 'sellerId' بناءً على التطبيق
        const field = role === 'seller' ? 'sellerId' : 'buyerId';

        const snapshot = await db.collection('deals')
            .where(field, '==', userId)
            .orderBy('timestamp', 'desc')
            .get();

        const deals = [];
        snapshot.forEach(doc => deals.push({ id: doc.id, ...doc.data() }));
        res.json(deals);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;