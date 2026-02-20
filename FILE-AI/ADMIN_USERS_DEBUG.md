# 🔍 تشخيص مشكلة عدم ظهور المستخدمين في صفحة المستخدمين

## 📋 المشكلة

المستخدمون لا يظهرون في تبويب "المستخدمين" في لوحة القيادة الإدارية.

## 🔍 الأسباب المحتملة

### 1. ❌ السيرفر لا يحتوي على endpoint `/admin/users`

**الملف المتأثر**: `lib/services/api_service.dart` (السطر 552)

التطبيق يحاول الاتصال بـ:
```
GET http://72.60.80.201:3001/api/admin/users
```

**الحل**: يجب إضافة هذا الـ endpoint على السيرفر البعيد (`~/aqar-server/index.js`)

### 2. ❌ المستخدم الحالي ليس Admin

حتى لو كان الـ endpoint موجود، قد يكون المستخدم الحالي ليس لديه صلاحيات admin.

### 3. ❌ مشاكل في الـ Authorization Token

قد يكون الـ token المرسل غير صحيح أو منتهي الصلاحية.

## ✅ التحديثات المطبقة

### 1. إضافة Debug Logs في `api_service.dart`

```dart
static Future<List<Map<String, dynamic>>> fetchAllUsers() async {
  try {
    debugPrint('🌐 [API] Fetching all users from: $baseUrl/admin/users');
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users'),
      headers: headers,
    );
    debugPrint('📡 [API] Users response status: ${response.statusCode}');
    debugPrint('📦 [API] Users response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      debugPrint('✅ [API] Successfully fetched ${data.length} users');
      return List<Map<String, dynamic>>.from(data);
    } else {
      debugPrint('❌ [API] Failed to fetch users: ${response.statusCode}');
      debugPrint('📄 [API] Error body: ${response.body}');
    }
  } catch (e) {
    debugPrint('💥 [API] Exception while fetching users: $e');
  }
  return [];
}
```

### 2. تحسين معالجة الأخطاء في `admin_dashboard_screen.dart`

الآن الصفحة تعرض:
- ✅ رسالة خطأ واضحة إذا فشل التحميل
- ✅ زر "إعادة المحاولة"
- ✅ أيقونة واضحة عند عدم وجود مستخدمين

## 🧪 اختبار المشكلة

### الخطوة 1: افتح التطبيق وشغّل Debug Mode

```bash
flutter run
```

### الخطوة 2: اذهب إلى لوحة القيادة وافتح تبويب "المستخدمين"

### الخطوة 3: راقب الـ Console Logs

ابحث عن الرسائل التالية:
```
🌐 [API] Fetching all users from: http://72.60.80.201:3001/api/admin/users
📡 [API] Users response status: XXX
```

### السيناريوهات المتوقعة:

#### ✅ إذا كان Response: 200
```
✅ [API] Successfully fetched X users
```
**المشكلة**: التطبيق يعمل بشكل صحيح، المشكلة قد تكون في عدم وجود مستخدمين في قاعدة البيانات.

#### ❌ إذا كان Response: 404
```
❌ [API] Failed to fetch users: 404
```
**المشكلة**: الـ endpoint `/admin/users` غير موجود على السيرفر.
**الحل**: أضف الـ endpoint على السيرفر.

#### ❌ إذا كان Response: 401/403
```
❌ [API] Failed to fetch users: 401
```
**المشكلة**: المستخدم الحالي ليس لديه صلاحيات admin أو الـ token غير صحيح.
**الحل**: تأكد من أن المستخدم الحالي لديه `isAdmin: true` في قاعدة البيانات.

#### ❌ إذا كان Exception
```
💥 [API] Exception while fetching users: SocketException...
```
**المشكلة**: السيرفر غير متاح أو مشكلة في الاتصال بالإنترنت.

## 🔧 الحل المطلوب على السيرفر

### يجب إضافة Endpoint جديد في `~/aqar-server/index.js`:

```javascript
// Admin Middleware - للتحقق من صلاحيات Admin
const adminOnly = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];
    if (!token) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    // فك تشفير الـ token والتحقق من isAdmin
    const decodedToken = await admin.auth().verifyIdToken(token);
    const userDoc = await db.collection('users').doc(decodedToken.uid).get();
    
    if (!userDoc.exists || !userDoc.data()?.isAdmin) {
      return res.status(403).json({ error: 'Forbidden - Admin only' });
    }

    req.userId = decodedToken.uid;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

// GET /api/admin/users - جلب جميع المستخدمين
router.get('/admin/users', adminOnly, async (req, res) => {
  try {
    const usersSnapshot = await db.collection('users').get();
    const users = [];
    
    usersSnapshot.forEach(doc => {
      users.push({
        id: doc.id,
        ...doc.data(),
      });
    });
    
    res.json(users);
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// POST /api/admin/users/:userId/ban - حظر/إلغاء حظر مستخدم
router.post('/admin/users/:userId/ban', adminOnly, async (req, res) => {
  try {
    const { userId } = req.params;
    const { isBanned } = req.body;
    
    await db.collection('users').doc(userId).update({
      isBanned: isBanned === true,
    });
    
    res.json({ success: true });
  } catch (error) {
    console.error('Error updating user ban status:', error);
    res.status(500).json({ error: 'Failed to update user' });
  }
});

// GET /api/admin/stats - جلب الإحصائيات
router.get('/admin/stats', adminOnly, async (req, res) => {
  try {
    const [usersSnap, propertiesSnap, chatsSnap] = await Promise.all([
      db.collection('users').get(),
      db.collection('properties').get(),
      db.collection('chats').get(),
    ]);
    
    res.json({
      users: usersSnap.size,
      properties: propertiesSnap.size,
      chats: chatsSnap.size,
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// GET /api/admin/chats - جلب جميع المحادثات
router.get('/admin/chats', adminOnly, async (req, res) => {
  try {
    const chatsSnapshot = await db.collection('chats').get();
    const chats = [];
    
    chatsSnapshot.forEach(doc => {
      chats.push({
        id: doc.id,
        ...doc.data(),
      });
    });
    
    res.json(chats);
  } catch (error) {
    console.error('Error fetching chats:', error);
    res.status(500).json({ error: 'Failed to fetch chats' });
  }
});

// GET /api/admin/reports - جلب جميع البلاغات
router.get('/admin/reports', adminOnly, async (req, res) => {
  try {
    const reportsSnapshot = await db.collection('reports').get();
    const reports = [];
    
    reportsSnapshot.forEach(doc => {
      reports.push({
        id: doc.id,
        ...doc.data(),
      });
    });
    
    res.json(reports);
  } catch (error) {
    console.error('Error fetching reports:', error);
    res.status(500).json({ error: 'Failed to fetch reports' });
  }
});
```

## 📝 ملاحظات مهمة

1. **صلاحيات Admin**: تأكد من وجود مستخدم واحد على الأقل في قاعدة البيانات لديه `isAdmin: true`

2. **إعداد المستخدم Admin يدوياً عبر Firebase Console**:
   - افتح Firebase Console
   - اذهب إلى Firestore Database
   - افتح collection `users`
   - اختر المستخدم المطلوب
   - أضف حقل جديد: `isAdmin` = `true`

3. **الـ Token**: التطبيق يستخدم token مؤقت بصيغة `signup_${userId}` وليس token حقيقي من Firebase. قد تحتاج لإصلاح هذا أيضاً.

## 🚀 الخطوات التالية

### 1. اختبار التطبيق الآن
```bash
flutter run
```

### 2. راقب الـ Console للرسائل الجديدة

### 3. إذا كان الـ endpoint غير موجود، اتصل بالسيرفر وأضف الكود أعلاه

```bash
ssh root@72.60.80.201
cd ~/aqar-server
nano index.js
# أضف الكود أعلاه
# احفظ بـ Ctrl+O ثم Ctrl+X
pm2 restart all
```

### 4. اختبر مرة أخرى بعد إضافة الـ endpoints

## 📊 ملخص التغييرات

| الملف | التعديل | الحالة |
|------|---------|--------|
| `lib/services/api_service.dart` | إضافة debug logs | ✅ مكتمل |
| `lib/screens/admin_dashboard_screen.dart` | تحسين معالجة الأخطاء | ✅ مكتمل |
| `~/aqar-server/index.js` (السيرفر) | إضافة admin endpoints | ⏳ مطلوب |

