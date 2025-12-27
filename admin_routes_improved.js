const express = require('express');
const router = express.Router();
const { db } = require('../firebaseConfig');

// استيراد middleware التحقق من التوكن
const { verifyToken } = require('../middleware/auth'); 

// ==================== MIDDLEWARE ====================

/**
 * 🔐 التحقق من صلاحية المدير/الأدمن
 * يتحقق من أن المستخدم موجود وله صلاحيات إدارية
 */
const checkAdmin = async (req, res, next) => {
    const userId = req.userId; // من verifyToken middleware
    
    if (!userId) {
        console.error('[Admin Check] لا يوجد userId في الطلب');
        return res.status(401).json({ 
            message: 'يجب تسجيل الدخول أولاً.',
            code: 'UNAUTHORIZED'
        });
    }

    try {
        const userDoc = await db.collection('users').doc(userId).get();
        
        if (!userDoc.exists) {
            console.error(`[Admin Check] المستخدم ${userId} غير موجود في قاعدة البيانات`);
            return res.status(404).json({ 
                message: 'المستخدم غير موجود.',
                code: 'USER_NOT_FOUND'
            });
        }

        const userData = userDoc.data();
        const isAdmin = userData.isAdmin || false;
        const isSuperAdmin = userData.isSuperAdmin || false;

        // التحقق من أن المستخدم أدمن أو مدير عام
        if (!isAdmin && !isSuperAdmin) {
            console.warn(`[Admin Check] محاولة وصول غير مصرح من المستخدم ${userId}`);
            return res.status(403).json({ 
                message: 'أنت لا تملك صلاحيات إدارية.',
                code: 'FORBIDDEN'
            });
        }

        // إضافة بيانات المستخدم الأدمن إلى req للاستخدام في الـ routes
        req.adminUser = userData;
        req.isSuperAdmin = isSuperAdmin;
        next();
    } catch (error) {
        console.error('[Admin Check] خطأ في التحقق من الصلاحيات:', error);
        res.status(500).json({ 
            message: 'حدث خطأ في التحقق من الصلاحيات.',
            code: 'SERVER_ERROR',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
};

/**
 * 🛡️ التحقق من صلاحية المدير العام فقط
 * يتحقق من أن المستخدم لديه صلاحيات مدير عام
 */
const checkSuperAdmin = async (req, res, next) => {
    if (!req.isSuperAdmin) {
        console.warn(`[SuperAdmin Check] محاولة وصول غير مصرح - المستخدم ليس مدير عام`);
        return res.status(403).json({ 
            message: 'هذه العملية تتطلب صلاحيات المدير العام.',
            code: 'SUPER_ADMIN_REQUIRED'
        });
    }
    next();
};

/**
 * 🛡️ التحقق من صحة بيانات الإعدادات
 */
const validateSettings = (settings) => {
    const errors = [];
    
    if (settings.maintenance_mode !== undefined && typeof settings.maintenance_mode !== 'boolean') {
        errors.push('maintenance_mode يجب أن يكون boolean');
    }
    
    if (settings.maintenance_message !== undefined && typeof settings.maintenance_message !== 'string') {
        errors.push('maintenance_message يجب أن يكون نص');
    }
    
    if (settings.min_version !== undefined && typeof settings.min_version !== 'string') {
        errors.push('min_version يجب أن يكون نص');
    }
    
    return errors;
};

// ==================== DASHBOARD ROUTES ====================

/**
 * 📊 1. جلب الإحصائيات العامة (نظرة عامة)
 * GET /admin/stats
 */
router.get('/stats', verifyToken, checkAdmin, async (req, res) => {
    try {
        console.log(`[Stats] جلب الإحصائيات من قبل: ${req.adminUser.email}`);
        
        // جلب العد من Firestore
        const usersSnap = await db.collection('users').get();
        const propsSnap = await db.collection('properties').get();
        const chatsSnap = await db.collection('chats').get();
        const reportsSnap = await db.collection('reports').get();

        // عد المستخدمين النشطين والمحظورين
        let activeUsers = 0;
        let bannedUsers = 0;
        usersSnap.forEach(doc => {
            const user = doc.data();
            if (user.isBanned) {
                bannedUsers++;
            } else {
                activeUsers++;
            }
        });

        const stats = {
            totalUsers: usersSnap.size,
            activeUsers,
            bannedUsers,
            totalProperties: propsSnap.size,
            totalChats: chatsSnap.size,
            totalReports: reportsSnap.size,
            timestamp: new Date().toISOString()
        };

        console.log('[Stats] تم جلب الإحصائيات بنجاح:', stats);
        res.status(200).json(stats);
    } catch (error) {
        console.error('[Stats] خطأ في جلب الإحصائيات:', error);
        res.status(500).json({ 
            message: 'فشل جلب الإحصائيات.',
            code: 'FETCH_STATS_ERROR',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * 👥 2. جلب جميع المستخدمين (المستخدمين)
 * GET /admin/users
 */
router.get('/users', verifyToken, checkAdmin, async (req, res) => {
    try {
        console.log(`[Users] جلب قائمة المستخدمين من قبل: ${req.adminUser.email}`);
        
        const snapshot = await db.collection('users').orderBy('createdAt', 'desc').get();
        const users = [];

        snapshot.forEach(doc => {
            const userData = doc.data();
            users.push({
                id: doc.id,
                email: userData.email || '',
                username: userData.username || '',
                phone: userData.phone || '',
                isAdmin: userData.isAdmin || false,
                isSuperAdmin: userData.isSuperAdmin || false,
                isBanned: userData.isBanned || false,
                isOnline: userData.isOnline || false,
                lastSeen: userData.lastSeen || null,
                createdAt: userData.createdAt || null,
                reputationScore: userData.reputationScore || 0,
                profileImage: userData.profileImage || null
            });
        });

        console.log(`[Users] تم جلب ${users.length} مستخدم`);
        res.status(200).json(users);
    } catch (error) {
        console.error('[Users] خطأ في جلب المستخدمين:', error);
        res.status(500).json({ 
            message: 'فشل جلب المستخدمين.',
            code: 'FETCH_USERS_ERROR',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * 🚫 3. حظر/فك حظر مستخدم
 * POST /admin/users/:id/ban
 * Body: { isBanned: boolean }
 */
router.post('/users/:id/ban', verifyToken, checkAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const { isBanned } = req.body;

        // Validation
        if (typeof isBanned !== 'boolean') {
            return res.status(400).json({ 
                message: 'isBanned يجب أن يكون true أو false',
                code: 'INVALID_INPUT'
            });
        }

        if (id === req.adminUser.uid) {
            return res.status(400).json({ 
                message: 'لا يمكنك حظر حسابك الخاص',
                code: 'SELF_BAN_ERROR'
            });
        }

        // التحقق من وجود المستخدم
        const userDoc = await db.collection('users').doc(id).get();
        if (!userDoc.exists) {
            return res.status(404).json({ 
                message: 'المستخدم غير موجود.',
                code: 'USER_NOT_FOUND'
            });
        }

        // تحديث حالة المستخدم
        await db.collection('users').doc(id).update({ 
            isBanned,
            banUpdatedAt: new Date().toISOString(),
            banUpdatedBy: req.adminUser.email
        });

        console.log(`[Ban] تم ${isBanned ? 'حظر' : 'فك حظر'} المستخدم ${id} من قبل ${req.adminUser.email}`);

        res.status(200).json({ 
            message: `تم ${isBanned ? 'حظر' : 'فك حظر'} المستخدم بنجاح`,
            userId: id,
            isBanned,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('[Ban] خطأ في حظر/فك حظر المستخدم:', error);
        res.status(500).json({ 
            message: 'فشل تحديث حالة المستخدم.',
            code: 'UPDATE_USER_ERROR',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * 👤 4. ترقية/تخفيض رتبة المدير العادي
 * POST /admin/users/:id/admin
 * Body: { isAdmin: boolean }
 */
router.post('/users/:id/admin', verifyToken, checkAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const { isAdmin } = req.body;

        // Validation
        if (typeof isAdmin !== 'boolean') {
            return res.status(400).json({ 
                message: 'isAdmin يجب أن يكون true أو false',
                code: 'INVALID_INPUT'
            });
        }

        if (id === req.userId) {
            return res.status(400).json({ 
                message: 'لا يمكنك تعديل صلاحياتك الخاصة',
                code: 'SELF_MODIFY_ERROR'
            });
        }

        // التحقق من وجود المستخدم
        const userDoc = await db.collection('users').doc(id).get();
        if (!userDoc.exists) {
            return res.status(404).json({ 
                message: 'المستخدم غير موجود.',
                code: 'USER_NOT_FOUND'
            });
        }

        // تحديث صلاحية المدير
        await db.collection('users').doc(id).update({ 
            isAdmin,
            adminUpdatedAt: new Date().toISOString(),
            adminUpdatedBy: req.adminUser.email
        });

        console.log(`[Admin] تم ${isAdmin ? 'ترقية' : 'تخفيض'} المستخدم ${id} ${isAdmin ? 'لمدير' : 'من مدير'} من قبل ${req.adminUser.email}`);

        res.status(200).json({ 
            message: `تم ${isAdmin ? 'ترقية المستخدم لمدير' : 'تخفيض رتبة المستخدم'} بنجاح`,
            userId: id,
            isAdmin,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('[Admin] خطأ في تحديث صلاحيات المدير:', error);
        res.status(500).json({ 
            message: 'فشل تحديث صلاحيات المدير.',
            code: 'UPDATE_ADMIN_ERROR',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * 🛡️ 5. ترقية/تخفيض رتبة المدير العام
 * POST /admin/users/:id/super-admin
 * Body: { isSuperAdmin: boolean }
 * ⚠️ فقط المدير العام يستطيع استخدام هذا الـ endpoint
 */
router.post('/users/:id/super-admin', verifyToken, checkAdmin, checkSuperAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const { isSuperAdmin } = req.body;

        // Validation
        if (typeof isSuperAdmin !== 'boolean') {
            return res.status(400).json({ 
                message: 'isSuperAdmin يجب أن يكون true أو false',
                code: 'INVALID_INPUT'
            });
        }

        if (id === req.userId) {
            return res.status(400).json({ 
                message: 'لا يمكنك تعديل صلاحياتك الخاصة',
                code: 'SELF_MODIFY_ERROR'
            });
        }

        // التحقق من وجود المستخدم
        const userDoc = await db.collection('users').doc(id).get();
        if (!userDoc.exists) {
            return res.status(404).json({ 
                message: 'المستخدم غير موجود.',
                code: 'USER_NOT_FOUND'
            });
        }

        // تحديث صلاحية المدير العام
        await db.collection('users').doc(id).update({ 
            isSuperAdmin,
            superAdminUpdatedAt: new Date().toISOString(),
            superAdminUpdatedBy: req.adminUser.email
        });

        console.log(`[SuperAdmin] تم ${isSuperAdmin ? 'ترقية' : 'تخفيض'} المستخدم ${id} ${isSuperAdmin ? 'لمدير عام' : 'من مدير عام'} من قبل ${req.adminUser.email}`);

        res.status(200).json({ 
            message: `تم ${isSuperAdmin ? 'ترقية المستخدم لمدير عام' : 'تخفيض رتبة المستخدم'} بنجاح`,
            userId: id,
            isSuperAdmin,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('[SuperAdmin] خطأ في تحديث صلاحيات المدير العام:', error);
        res.status(500).json({ 
            message: 'فشل تحديث صلاحيات المدير العام.',
            code: 'UPDATE_SUPERADMIN_ERROR',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * 💬 6. جلب المحادثات الأخيرة (المراقبة المتقدمة)
 * GET /admin/chats
 */
router.get('/chats', verifyToken, checkAdmin, async (req, res) => {
    try {
        console.log(`[Chats] جلب المحادثات من قبل: ${req.adminUser.email}`);
        
        const snapshot = await db.collection('chats')
            .orderBy('lastMessageTimestamp', 'desc')
            .limit(100)
            .get();

        const chatsWithDetails = [];

        for (const doc of snapshot.docs) {
            const chatData = doc.data();
            const chatId = doc.id;

            // جلب معلومات المستخدمين
            let user1Data = null;
            let user2Data = null;

            if (chatData.user1Id) {
                const user1Doc = await db.collection('users').doc(chatData.user1Id).get();
                if (user1Doc.exists) {
                    const u1 = user1Doc.data();
                    user1Data = {
                        id: chatData.user1Id,
                        username: u1.username || 'مستخدم',
                        email: u1.email || '',
                        profileImage: u1.profileImage || null,
                        isOnline: u1.isOnline || false,
                        isBanned: u1.isBanned || false
                    };
                }
            }

            if (chatData.user2Id) {
                const user2Doc = await db.collection('users').doc(chatData.user2Id).get();
                if (user2Doc.exists) {
                    const u2 = user2Doc.data();
                    user2Data = {
                        id: chatData.user2Id,
                        username: u2.username || 'مستخدم',
                        email: u2.email || '',
                        profileImage: u2.profileImage || null,
                        isOnline: u2.isOnline || false,
                        isBanned: u2.isBanned || false
                    };
                }
            }

            // عد الرسائل في هذه المحادثة
            const messagesSnapshot = await db.collection('chats')
                .doc(chatId)
                .collection('messages')
                .get();

            chatsWithDetails.push({
                id: chatId,
                user1: user1Data,
                user2: user2Data,
                lastMessage: chatData.lastMessage || '',
                lastMessageTimestamp: chatData.lastMessageTimestamp || null,
                propertyId: chatData.propertyId || null,
                messagesCount: messagesSnapshot.size,
                createdAt: chatData.createdAt || null
            });
        }

        console.log(`[Chats] تم جلب ${chatsWithDetails.length} محادثة مع التفاصيل`);
        res.status(200).json(chatsWithDetails);
    } catch (error) {
        console.error('[Chats] خطأ في جلب المحادثات:', error);
        res.status(500).json({ 
            message: 'فشل جلب المحادثات.',
            code: 'FETCH_CHATS_ERROR',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * 💬 6.1. جلب رسائل محادثة معينة (للمراقبة)
 * GET /admin/chats/:chatId/messages
 * ✅ Enhanced: Returns participants array with complete user data and messages with sender names
 */
router.get('/chats/:chatId/messages', verifyToken, checkAdmin, async (req, res) => {
    try {
        const { chatId } = req.params;
        console.log(`[Chat Messages] جلب رسائل المحادثة ${chatId} من قبل: ${req.adminUser.email}`);

        // التحقق من وجود المحادثة
        const chatDoc = await db.collection('chats').doc(chatId).get();
        if (!chatDoc.exists) {
            console.warn(`[Chat Messages] المحادثة ${chatId} غير موجودة`);
            return res.status(404).json({
                message: 'المحادثة غير موجودة.',
                code: 'CHAT_NOT_FOUND',
                participants: [],
                messages: [],
                totalMessages: 0
            });
        }

        const chatData = chatDoc.data();
        const participants = [];

        // 👥 جلب بيانات المشاركين (user1 و user2)
        if (chatData.user1Id) {
            try {
                const user1Doc = await db.collection('users').doc(chatData.user1Id).get();
                if (user1Doc.exists) {
                    const u1Data = user1Doc.data();
                    participants.push({
                        id: chatData.user1Id,
                        username: u1Data.username || 'مستخدم',
                        email: u1Data.email || '',
                        profileImage: u1Data.profileImage || null,
                        isOnline: u1Data.isOnline || false,
                        isBanned: u1Data.isBanned || false
                    });
                } else {
                    console.warn(`[Chat Messages] المستخدم ${chatData.user1Id} غير موجود`);
                }
            } catch (err) {
                console.error(`[Chat Messages] خطأ في جلب بيانات user1: ${err.message}`);
            }
        }

        if (chatData.user2Id) {
            try {
                const user2Doc = await db.collection('users').doc(chatData.user2Id).get();
                if (user2Doc.exists) {
                    const u2Data = user2Doc.data();
                    participants.push({
                        id: chatData.user2Id,
                        username: u2Data.username || 'مستخدم',
                        email: u2Data.email || '',
                        profileImage: u2Data.profileImage || null,
                        isOnline: u2Data.isOnline || false,
                        isBanned: u2Data.isBanned || false
                    });
                } else {
                    console.warn(`[Chat Messages] المستخدم ${chatData.user2Id} غير موجود`);
                }
            } catch (err) {
                console.error(`[Chat Messages] خطأ في جلب بيانات user2: ${err.message}`);
            }
        }

        // 📨 جلب الرسائل مع أسماء المرسلين
        const messagesSnapshot = await db.collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', 'asc')
            .get();

        const messages = [];
        for (const doc of messagesSnapshot.docs) {
            const msgData = doc.data();
            let senderName = 'مستخدم';

            // محاولة جلب اسم المرسل من قاعدة البيانات
            if (msgData.senderId) {
                try {
                    const senderDoc = await db.collection('users').doc(msgData.senderId).get();
                    if (senderDoc.exists) {
                        senderName = senderDoc.data().username || 'مستخدم';
                    }
                } catch (err) {
                    console.warn(`[Chat Messages] تعذر جلب اسم المرسل ${msgData.senderId}: ${err.message}`);
                }
            }

            // بناء كائن الرسالة مع اسم المرسل والوقت الموحد
            messages.push({
                id: doc.id,
                senderId: msgData.senderId || null,
                senderName: senderName,
                text: msgData.text || msgData.content || '',
                content: msgData.content || msgData.text || '',
                imageUrls: msgData.imageUrls || msgData.images || [],
                images: msgData.images || msgData.imageUrls || [],
                timestamp: msgData.timestamp || msgData.createdAt || new Date().toISOString(),
                createdAt: msgData.createdAt || msgData.timestamp || new Date().toISOString(),
                ...msgData
            });
        }

        console.log(`[Chat Messages] تم جلب ${messages.length} رسالة مع ${participants.length} مشارك`);

        res.status(200).json({
            chatId,
            chatData,
            participants, // ✅ الآن يتم إرجاع المشاركين
            messages,
            totalMessages: messages.length,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('[Chat Messages] خطأ في جلب رسائل المحادثة:', error);
        res.status(500).json({
            message: 'فشل جلب رسائل المحادثة.',
            code: 'FETCH_MESSAGES_ERROR',
            participants: [],
            messages: [],
            totalMessages: 0,
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * 💬 6.2. حذف محادثة (في حالة المخالفة)
 * DELETE /admin/chats/:chatId
 */
router.delete('/chats/:chatId', verifyToken, checkAdmin, async (req, res) => {
    try {
        const { chatId } = req.params;
        console.log(`[Delete Chat] حذف المحادثة ${chatId} من قبل: ${req.adminUser.email}`);

        // التحقق من وجود المحادثة
        const chatDoc = await db.collection('chats').doc(chatId).get();
        if (!chatDoc.exists) {
            return res.status(404).json({
                message: 'المحادثة غير موجودة.',
                code: 'CHAT_NOT_FOUND'
            });
        }

        // حذف جميع الرسائل أولاً
        const messagesSnapshot = await db.collection('chats')
            .doc(chatId)
            .collection('messages')
            .get();

        const batch = db.batch();
        messagesSnapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
        });

        // حذف المحادثة نفسها
        batch.delete(db.collection('chats').doc(chatId));

        await batch.commit();

        console.log(`[Delete Chat] تم حذف المحادثة ${chatId} و ${messagesSnapshot.size} رسالة`);
        res.status(200).json({
            message: 'تم حذف المحادثة بنجاح',
            chatId,
            deletedMessages: messagesSnapshot.size,
            deletedBy: req.adminUser.email,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('[Delete Chat] خطأ في حذف المحادثة:', error);
        res.status(500).json({
            message: 'فشل حذف المحادثة.',
            code: 'DELETE_CHAT_ERROR',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * 📋 7. جلب البلاغات/الشكاوى (البلاغات)
 * GET /admin/reports
 */
router.get('/reports', verifyToken, checkAdmin, async (req, res) => {
    try {
        console.log(`[Reports] جلب البلاغات من قبل: ${req.adminUser.email}`);
        
        const snapshot = await db.collection('reports')
            .orderBy('timestamp', 'desc')
            .get();

        const reports = [];
        snapshot.forEach(doc => {
            reports.push({
                id: doc.id,
                ...doc.data()
            });
        });

        console.log(`[Reports] تم جلب ${reports.length} بلاغ`);
        res.status(200).json(reports);
    } catch (error) {
        console.error('[Reports] خطأ في جلب البلاغات:', error);
        // إذا لم تكن المجموعة موجودة، نرجع مصفوفة فارغة
        res.status(200).json([]);
    }
});

// ==================== SETTINGS ROUTES ====================

/**
 * ⚙️ 8. جلب إعدادات التطبيق
 * GET /admin/settings
 */
router.get('/settings', verifyToken, checkAdmin, async (req, res) => {
    try {
        console.log(`[Settings] جلب الإعدادات من قبل: ${req.adminUser.email}`);
        
        const settingsDoc = await db.collection('settings').doc('app').get();
        
        // الإعدادات الافتراضية
        const defaultSettings = {
            min_version: '1.0.0',
            maintenance_mode: false,
            maintenance_message: 'التطبيق مغلق حالياً للصيانة، يرجى المحاولة لاحقاً.'
        };

        let settings = defaultSettings;

        if (settingsDoc.exists) {
            // دمج الإعدادات المحفوظة مع الافتراضية
            settings = {
                ...defaultSettings,
                ...settingsDoc.data()
            };
        }

        console.log('[Settings] تم جلب الإعدادات بنجاح:', settings);
        res.status(200).json(settings);
    } catch (error) {
        console.error('[Settings] خطأ في جلب الإعدادات:', error);
        res.status(500).json({ 
            message: 'فشل جلب إعدادات التطبيق.',
            code: 'FETCH_SETTINGS_ERROR',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * ⚙️ 9. تحديث إعدادات التطبيق
 * POST /admin/settings
 * Body: { min_version?, maintenance_mode?, maintenance_message? }
 */
router.post('/settings', verifyToken, checkAdmin, async (req, res) => {
    try {
        const newSettings = req.body;
        
        console.log(`[Settings] محاولة تحديث الإعدادات من قبل: ${req.adminUser.email}`);
        console.log('[Settings] الإعدادات الجديدة:', newSettings);

        // التحقق من صحة البيانات
        const validationErrors = validateSettings(newSettings);
        if (validationErrors.length > 0) {
            return res.status(400).json({ 
                message: 'بيانات غير صحيحة',
                code: 'VALIDATION_ERROR',
                errors: validationErrors
            });
        }

        // إضافة بيانات التحديث (metadata)
        const settingsToSave = {
            ...newSettings,
            updatedAt: new Date().toISOString(),
            updatedBy: req.adminUser.email
        };

        // حفظ الإعدادات في Firestore
        await db.collection('settings').doc('app').set(settingsToSave, { merge: true });

        console.log('[Settings] تم تحديث الإعدادات بنجاح');
        
        res.status(200).json({ 
            message: 'تم تحديث إعدادات التطبيق بنجاح.',
            code: 'SETTINGS_UPDATED',
            settings: settingsToSave,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('[Settings] خطأ في تحديث الإعدادات:', error);
        res.status(500).json({ 
            message: 'فشل تحديث إعدادات التطبيق.',
            code: 'UPDATE_SETTINGS_ERROR',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// ==================== HEALTH CHECK ====================

/**
 * 🏥 صحة نقطة النهاية الإدارية
 * GET /admin/health
 */
router.get('/health', verifyToken, checkAdmin, async (req, res) => {
    try {
        res.status(200).json({ 
            status: 'ok',
            message: 'Admin routes are working',
            admin: req.adminUser.email,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ 
            status: 'error',
            message: 'Admin routes are not responding',
            error: error.message
        });
    }
});

// ==================== PUBLIC ROUTES (بدون صلاحيات) ====================

/**
 * ⚙️ جلب إعدادات التطبيق (عام - بدون صلاحيات admin)
 * GET /settings (public endpoint)
 * هذا الـ endpoint يُسمح لجميع المستخدمين بالوصول إليه
 */
router.get('/settings/public', async (req, res) => {
    try {
        console.log('[Settings Public] جلب إعدادات التطبيق (عام)');
        
        const settingsDoc = await db.collection('settings').doc('app').get();
        
        // الإعدادات الافتراضية
        const defaultSettings = {
            min_version: '1.0.0',
            maintenance_mode: false,
            maintenance_message: 'التطبيق مغلق حالياً للصيانة، يرجى المحاولة لاحقاً.'
        };

        let settings = defaultSettings;

        if (settingsDoc.exists) {
            // دمج الإعدادات المحفوظة مع الافتراضية
            settings = {
                ...defaultSettings,
                ...settingsDoc.data()
            };
        }

        // إرجاع الإعدادات العامة فقط (بدون معلومات حساسة)
        const publicSettings = {
            min_version: settings.min_version,
            maintenance_mode: settings.maintenance_mode,
            maintenance_message: settings.maintenance_message
        };

        console.log('[Settings Public] تم جلب الإعدادات بنجاح:', publicSettings);
        res.status(200).json(publicSettings);
    } catch (error) {
        console.error('[Settings Public] خطأ في جلب الإعدادات:', error);
        // في حالة الخطأ، نرجع القيم الافتراضية
        res.status(200).json({
            min_version: '1.0.0',
            maintenance_mode: false,
            maintenance_message: 'التطبيق مغلق حالياً للصيانة، يرجى المحاولة لاحقاً.'
        });
    }
});

module.exports = router;
