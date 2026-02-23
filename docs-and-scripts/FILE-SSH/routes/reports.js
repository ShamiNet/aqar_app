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
        const { propertyId, propertyTitle, reason, description } = req.body;

        // تحقق بسيط
        if (!propertyId || !reason) {
            return res.status(400).json({
                message: 'البيانات ناقصة (propertyId, reason)',
                code: 'INVALID_INPUT'
            });
        }

        // جلب بيانات المبلغ
        let reporterInfo = {};
        try {
            const userDoc = await db.collection('users').doc(req.userId).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                reporterInfo = {
                    reporterName: userData.username || userData.email || 'مستخدم',
                    reporterEmail: userData.email || '',
                    reporterPhone: userData.phone || '',
                };
            }
        } catch (userError) {
            console.log('[Report] Could not fetch reporter info:', userError);
        }

        const reportData = {
            propertyId,
            propertyTitle: propertyTitle || 'عقار بدون عنوان',
            reason,
            description: description || '',
            reporterId: req.userId,
            ...reporterInfo,
            status: 'pending',
            timestamp: new Date().toISOString(),
            createdAt: new Date().toISOString(),
        };

        // حفظ في Firestore
        const docRef = await db.collection('reports').add(reportData);

        console.log(`[Report] New report added by ${req.userId}, ID: ${docRef.id}`);

        res.status(201).json({
            message: 'تم إرسال البلاغ بنجاح',
            reportId: docRef.id,
            data: {
                id: docRef.id,
                ...reportData
            }
        });

    } catch (error) {
        console.error('[Report Error]:', error);
        res.status(500).json({
            message: 'فشل إرسال البلاغ',
            code: 'SERVER_ERROR',
            error: error.message
        });
    }
});

/**
 * 📋 جلب بلاغ واحد بمعرفه
 * GET /api/reports/:reportId
 */
router.get('/:reportId', verifyToken, async (req, res) => {
    try {
        const { reportId } = req.params;

        const reportDoc = await db.collection('reports').doc(reportId).get();

        if (!reportDoc.exists) {
            return res.status(404).json({
                message: 'البلاغ غير موجود',
                code: 'NOT_FOUND'
            });
        }

        const reportData = reportDoc.data();

        res.json({
            id: reportDoc.id,
            ...reportData
        });

    } catch (error) {
        console.error('[Report Fetch Error]:', error);
        res.status(500).json({
            message: 'خطأ في جلب البلاغ',
            code: 'SERVER_ERROR'
        });
    }
});

/**
 * 📊 جلب جميع البلاغات (للـ Admin)
 * GET /api/admin/reports
 */
router.get('/admin/list', verifyToken, async (req, res) => {
    try {
        // تحقق من أن المستخدم admin
        const userDoc = await db.collection('users').doc(req.userId).get();
        if (!userDoc.exists || !userDoc.data().isAdmin) {
            return res.status(403).json({
                message: 'غير مصرح',
                code: 'UNAUTHORIZED'
            });
        }

        const reportsSnapshot = await db.collection('reports')
            .orderBy('timestamp', 'desc')
            .get();

        const reports = [];
        reportsSnapshot.forEach(doc => {
            reports.push({
                id: doc.id,
                ...doc.data()
            });
        });

        res.json(reports);

    } catch (error) {
        console.error('[Reports List Error]:', error);
        res.status(500).json({
            message: 'خطأ في جلب البلاغات',
            code: 'SERVER_ERROR'
        });
    }
});

module.exports = router;