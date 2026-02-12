// routes/auth.js
const express = require('express');
const router = express.Router();
const { db } = require('../firebaseConfig');
const admin = require('firebase-admin');
const axios = require('axios');
const { verifyToken } = require('../middleware/authMiddleware');

const FIREBASE_API_KEY = process.env.FIREBASE_API_KEY;

// ==========================================
// 1. تسجيل الدخول عبر Google (المسار الرئيسي)
// ==========================================
router.post('/google', async (req, res) => {
    const { idToken } = req.body;

    if (!idToken) {
        return res.status(400).json({ error: 'لم يتم استلام التوكن' });
    }

    try {
        // 1. تبديل توكن جوجل بتوكن فايربيس
        const firebaseResponse = await axios.post(
            `https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=${FIREBASE_API_KEY}`,
            {
                postBody: `id_token=${idToken}&providerId=google.com`,
                requestUri: "http://localhost",
                returnIdpCredential: true,
                returnSecureToken: true
            }
        );

        // البيانات القادمة من جوجل/فايربيس
        const { idToken: firebaseIdToken, refreshToken, localId, expiresIn, email, displayName, photoUrl } = firebaseResponse.data;    

        // 2. التعامل مع قاعدة البيانات
        const userRef = db.collection('users').doc(localId);
        const doc = await userRef.get();

        let userData = {};

        if (!doc.exists) {
            // مستخدم جديد
            userData = {
                uid: localId,
                email: email, // حفظ الإيميل
                username: displayName || 'مستخدم جوجل',
                displayName: displayName || 'مستخدم جوجل',
                profileImageUrl: photoUrl || '',
                phoneNumber: '',
                role: 'user',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                lastLogin: admin.firestore.FieldValue.serverTimestamp(),
                isBanned: false,
                isVerified: false,
                isAdmin: false,
                isOnline: true,
                balance: 0.0
            };
            await userRef.set(userData);
        } else {
            // مستخدم موجود
            userData = doc.data();

            if (userData.isBanned === true) {
                return res.status(403).json({ error: 'عذراً، هذا الحساب محظور من قبل الإدارة' });
            }

            // تحديث البيانات
            const updates = {
                lastLogin: admin.firestore.FieldValue.serverTimestamp(),
                isOnline: true
            };

            // ✅ إصلاح 1: إذا كان الإيميل مفقوداً في الداتابيز، نضعه الآن
            if ((!userData.email || userData.email === '') && email) {
                updates.email = email;
                userData.email = email;
            }

            // ✅ إصلاح 2 (المهم لك): إذا كان تاريخ الانضمام مفقوداً، نعتبره الآن
            if (!userData.createdAt) {
                updates.createdAt = admin.firestore.FieldValue.serverTimestamp();
                // تحديث المتغير المحلي ليرسله السيرفر في الرد فوراً
                userData.createdAt = { _seconds: Date.now() / 1000, _nanoseconds: 0 };
            }

            await userRef.update(updates);
        }



                  // 3. إرسال الرد
        res.status(200).json({
            token: firebaseIdToken,
            refreshToken: refreshToken,
            userId: localId,
            expiresIn: expiresIn,
            userData: userData,
            email: email // ✅ نرسل الإيميل بشكل صريح للتطبيق ليقوم بحفظه
        });

    } catch (error) {
        console.error('Google Auth Error:', error.response?.data || error.message);
        res.status(401).json({ error: 'فشل تسجيل الدخول عبر جوجل' });
    }
});

// ==========================================
// 2. تجديد التوكن
// ==========================================
router.post('/refresh', async (req, res) => {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh Token مطلوب' });
    }

    try {
      const response = await axios.post(
        `https://securetoken.googleapis.com/v1/token?key=${FIREBASE_API_KEY}`,
        {
          grant_type: 'refresh_token',
          refresh_token: refreshToken
        }
      );

      res.status(200).json({
        token: response.data.id_token,
        refreshToken: response.data.refresh_token,
        expiresIn: response.data.expires_in,
        userId: response.data.user_id
      });

    } catch (error) {
      res.status(401).json({ error: 'الجلسة منتهية' });
    }
});

// ==========================================
// 3. تسجيل الخروج
// ==========================================
router.post('/logout', verifyToken, async (req, res) => {
    try {
        if (req.user && req.user.uid) {
            await db.collection('users').doc(req.user.uid).update({
                isOnline: false,
                lastSeen: admin.firestore.FieldValue.serverTimestamp()
            });
        }
        res.status(200).json({ success: true });
    } catch (error) {
        res.status(500).json({ error: 'خطأ' });
    }
});

module.exports = router;