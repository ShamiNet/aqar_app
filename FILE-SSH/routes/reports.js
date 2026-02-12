// routes/reports.js
const express = require('express');
const router = express.Router();
const { db } = require('../firebaseConfig');
const { verifyToken } = require('../middleware/auth');

/**
 * 📨 إنشاء بلاغ جديد (متاح للمستخدمين العاديين)
 * POST /api/reports
 */
router.post('/', verifyToken, async (req, res) => {
    try {
        const { propertyId, reason, details } = req.body;

        // تحقق بسيط
        if (!propertyId || !reason) {
            return res.status(400).json({
                message: 'البيانات ناقصة (propertyId, reason)',
                code: 'INVALID_INPUT'
            });
        }

        const reportData = {
            propertyId,
            reason,
            details: details || '',
            reporterId: req.userId, // المعرف القادم من التوكن
            status: 'pending',
            timestamp: new Date().toISOString(),
            createdAt: new Date().toISOString()
        };

        // حفظ في Firestore
        const docRef = await db.collection('reports').add(reportData);

        console.log(`[Report] New report added by ${req.userId}, ID: ${docRef.id}`);

        res.status(201).json({
            message: 'تم إرسال البلاغ بنجاح',
            reportId: docRef.id
        });

    } catch (error) {
        console.error('[Report Error]:', error);
        res.status(500).json({
            message: 'فشل إرسال البلاغ',
            code: 'SERVER_ERROR'
        });
    }
});

module.exports = router;