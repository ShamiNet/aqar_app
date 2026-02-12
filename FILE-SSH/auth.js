// middleware/auth.js
const admin = require('firebase-admin');
const { db } = require('../firebaseConfig');

// ✅ التحقق من صحة التوكن (Bearer Token)
exports.verifyToken = async (req, res, next) => {
  try {
    const auth = req.headers.authorization || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;

    if (!token) {
      return res.status(401).json({ error: 'Unauthorized: No token provided' });
    }

    // التحقق من التوكن باستخدام Firebase Admin
    const decoded = await admin.auth().verifyIdToken(token);

    // ✅ الإصلاح هنا: تخزين الـ ID والتوكن بشكل صريح
    req.user = decoded;
    req.userId = decoded.uid; // <--- هذا السطر هو الذي يحل مشكلة التحديث (403)

    return next();
  } catch (e) {
    console.error('❌ [AUTH] Token verification failed:', e.message);
    return res.status(401).json({ error: 'Unauthorized: Invalid or expired token' });
  }
};

// ✅ التحقق من أن المستخدم أدمن
exports.checkAdmin = async (req, res, next) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const userDoc = await db.collection('users').doc(uid).get();
    const userData = userDoc.exists ? userDoc.data() : null;

    const isAdmin = userData?.isAdmin === true || userData?.role === 'admin' || userData?.role === 'super-admin';

    if (!isAdmin) {
      console.warn(`⚠️ [AUTH] Non-admin user attempted access: ${uid}`);
      return res.status(403).json({ error: 'Forbidden: Admin access required' });
    }

    req.userRole = userData?.role;
    return next();
  } catch (e) {
    console.error('❌ [AUTH] Admin check failed:', e.message);
    return res.status(500).json({ error: 'Server error' });
  }
};

// ✅ التحقق من أن المستخدم سوبر-أدمن
exports.checkSuperAdmin = async (req, res, next) => {
  try {
    const userRole = req.userRole;

    if (userRole !== 'super-admin') {
      return res.status(403).json({ error: 'Forbidden: Super-admin access required' });
    }

    return next();
  } catch (e) {
    console.error('❌ [AUTH] Super-admin check failed:', e.message);
    return res.status(500).json({ error: 'Server error' });
  }
};