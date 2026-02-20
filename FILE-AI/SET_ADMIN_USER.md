# 🔧 كيفية إعداد مستخدم Admin

## ✅ النتيجة من الاختبار

الـ endpoints موجودة على السيرفر:
- ✅ `/api/admin/users` - موجود
- ✅ `/api/admin/stats` - موجود  
- ✅ `/api/admin/chats` - موجود

لكنها تعطي **"Forbidden"** لأنها تحتاج authentication + صلاحيات admin.

## 🎯 الحل: إعداد مستخدم Admin

### الطريقة 1: عبر Firebase Console (الأسهل)

1. **افتح Firebase Console**:
   - اذهب إلى https://console.firebase.google.com
   - اختر مشروعك

2. **افتح Firestore Database**:
   - من القائمة الجانبية، اختر "Firestore Database"

3. **ابحث عن المستخدم**:
   - افتح collection `users`
   - اختر المستخدم الذي تريد جعله admin
   - أو استخدم حسابك الحالي

4. **أضف حقل `isAdmin`**:
   - اضغط على "Add field"
   - Field name: `isAdmin`
   - Type: `boolean`
   - Value: `true`
   - احفظ

5. **اختبر الآن**:
   - سجّل خروج من التطبيق
   - سجّل دخول مرة أخرى
   - اذهب إلى لوحة القيادة
   - افتح تبويب "المستخدمين"

---

### الطريقة 2: عبر سكريبت Firebase (للمتقدمين)

إذا كنت تريد إعداد admin عبر سكريبت، استخدم هذا الكود:

```javascript
// set_admin.js
const admin = require('firebase-admin');
const serviceAccount = require('./path/to/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function setAdminUser(email) {
  try {
    // ابحث عن المستخدم بالإيميل
    const usersSnapshot = await db.collection('users')
      .where('email', '==', email)
      .get();
    
    if (usersSnapshot.empty) {
      console.log('❌ User not found with email:', email);
      return;
    }
    
    // حدّث المستخدم الأول المطابق
    const userDoc = usersSnapshot.docs[0];
    await userDoc.ref.update({ isAdmin: true });
    
    console.log('✅ User is now admin:', userDoc.id);
    console.log('   Email:', email);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

// استخدم إيميلك هنا
setAdminUser('your-email@example.com');
```

**لتشغيله**:
```bash
node set_admin.js
```

---

### الطريقة 3: عبر الـ Server مباشرة

على السيرفر (`~/aqar-server/`), أضف endpoint مؤقت:

```javascript
// ⚠️ استخدم هذا فقط مرة واحدة ثم احذفه!
router.post('/admin/setup-first-admin', async (req, res) => {
  try {
    const { email, secretKey } = req.body;
    
    // كلمة سر مؤقتة للحماية
    if (secretKey !== 'YOUR_SECRET_SETUP_KEY_12345') {
      return res.status(403).json({ error: 'Invalid secret key' });
    }
    
    const usersSnapshot = await db.collection('users')
      .where('email', '==', email)
      .get();
    
    if (usersSnapshot.empty) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userDoc = usersSnapshot.docs[0];
    await userDoc.ref.update({ isAdmin: true });
    
    res.json({ 
      success: true, 
      message: 'User is now admin',
      userId: userDoc.id 
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

**لاستخدامه**:
```powershell
curl http://72.60.80.201:3001/api/admin/setup-first-admin -Method POST `
  -ContentType "application/json" `
  -Body '{"email":"your-email@example.com","secretKey":"YOUR_SECRET_SETUP_KEY_12345"}'
```

**⚠️ مهم جداً**: احذف هذا الـ endpoint بعد الاستخدام!

---

## 🧪 التحقق من نجاح الإعداد

### 1. تحقق عبر Firebase Console:
- افتح المستخدم في Firestore
- يجب أن ترى `isAdmin: true`

### 2. تحقق عبر التطبيق:
- سجّل دخول
- اذهب إلى لوحة القيادة
- إذا ظهرت لك لوحة القيادة، معناه الصلاحيات صحيحة
- افتح تبويب "المستخدمين"
- يجب أن تظهر قائمة المستخدمين الآن

### 3. راقب الـ Debug Logs:
عند فتح تبويب المستخدمين، يجب أن ترى في console:
```
🌐 [API] Fetching all users from: http://72.60.80.201:3001/api/admin/users
📡 [API] Users response status: 200
✅ [API] Successfully fetched X users
```

---

## 🚨 استكشاف الأخطاء

### إذا ظهر "Forbidden" بعد إضافة isAdmin:

1. **تأكد من تسجيل الخروج والدخول مرة أخرى**
   - Token القديم لا يحتوي على isAdmin

2. **تحقق من الـ token**:
   - افتح `SharedPreferences` في التطبيق
   - تأكد من وجود `auth_token`
   - إذا كان بصيغة `signup_userId`، تأكد أن السيرفر يتعامل معه بشكل صحيح

3. **تحقق من middleware في السيرفر**:
   - تأكد من وجود `adminOnly` middleware
   - تأكد من أنه يتحقق من `isAdmin` بشكل صحيح

### إذا ظهرت رسالة "لا يوجد مستخدمين":

1. **تأكد من وجود مستخدمين في Firestore**:
   - افتح Firebase Console → Firestore → users collection
   - يجب أن يكون هناك مستخدم واحد على الأقل

2. **تحقق من Debug Logs**:
   ```
   📦 [API] Users response body: [...]
   ```
   - إذا كان Response body فارغ `[]`، معناه لا يوجد users في قاعدة البيانات

---

## 📝 الخطوات التالية

1. ✅ أضف `isAdmin: true` لحسابك عبر Firebase Console
2. ✅ سجّل خروج وادخل مرة أخرى في التطبيق
3. ✅ افتح لوحة القيادة → تبويب المستخدمين
4. ✅ راقب الـ logs في console
5. ✅ يجب أن تظهر قائمة المستخدمين الآن!
