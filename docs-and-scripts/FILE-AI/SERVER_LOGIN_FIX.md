# 🔧 إصلاح مشكلة تسجيل الدخول في السيرفر

## 🔍 المشكلة المكتشفة

بعد الاختبار، تبين أن:
- ✅ **`/api/auth/signup` يعمل بشكل صحيح** - يمكن إنشاء مستخدمين جدد
- ❌ **`/api/auth/login` لا يعمل** - يعطي خطأ: `API key not valid. Please pass a valid API key.`

### الاختبار من PowerShell:

```powershell
# التسجيل - نجح ✅
curl http://72.60.80.201:3001/api/auth/signup -Method POST ...
# Response: 201 Created, userId: PKBpI62NFCZe7fxqPEpKPElQBXm2

# تسجيل الدخول - فشل ❌
curl http://72.60.80.201:3001/api/auth/login -Method POST ...
# Response: {"error":"API key not valid. Please pass a valid API key."}
```

## 🛠️ الحل المؤقت المطبق

تم تعديل التطبيق ليعمل **بدون استدعاء `/api/auth/login`**:

### التغييرات في `api_service.dart`:

```dart
static Future<void> signup(...) async {
  // ... إنشاء الحساب في السيرفر
  
  // ✅ حفظ البيانات محلياً مباشرة
  final data = jsonDecode(response.body);
  if (data['userId'] != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', data['userId']);
    await prefs.setString('user_data', jsonEncode({
      'email': email,
      'username': username,
      'phone': phone,
      'userId': data['userId'],
    }));
    await prefs.setString('auth_token', 'signup_${data['userId']}');
  }
}
```

### التغييرات في `login_screen.dart`:

```dart
Future<String?> _signupUser(SignupData data) async {
  // إزالة استدعاء ApiService.login()
  // الآن signup يحفظ البيانات تلقائياً
  await ApiService.signup(data.name!, data.password!, username, phone);
  return null; // نجاح
}
```

## ⚠️ القيود الحالية

### ما يعمل الآن:
- ✅ إنشاء حساب جديد
- ✅ الدخول التلقائي بعد التسجيل
- ✅ البقاء مسجلاً عند إعادة فتح التطبيق
- ✅ استخدام التطبيق بشكل طبيعي

### ما لا يعمل:
- ❌ **تسجيل الدخول لمستخدم موجود** (يستخدم `/api/auth/login` المعطل)
- ❌ تسجيل الدخول من جهاز آخر
- ❌ الحصول على token حقيقي من السيرفر

## 🔧 إصلاح السيرفر (مطلوب)

يجب إصلاح endpoint `/api/auth/login` على السيرفر. المشكلة على الأرجح في كيفية استخدام Firebase Admin SDK.

### كود السيرفر الحالي (المتوقع):

```javascript
// ❌ الكود الخاطئ - يسبب خطأ API key
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  
  try {
    // المشكلة: Firebase Admin SDK لا يوفر دالة مباشرة للتحقق من كلمة المرور
    // لأن Firebase Admin مصمم للعمليات الإدارية، ليس المصادقة
    const user = await admin.auth().getUserByEmail(email);
    // ⚠️ لا يمكن التحقق من password هنا!
    
  } catch (error) {
    res.status(401).json({ error: error.message });
  }
});
```

### الحل المقترح للسيرفر:

**خيار 1: استخدام Firebase Auth REST API**

```javascript
const axios = require('axios');

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  
  try {
    // استخدام Firebase Auth REST API للتحقق من بيانات الاعتماد
    const firebaseApiKey = 'YOUR_FIREBASE_WEB_API_KEY'; // من firebase_options.dart
    const response = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${firebaseApiKey}`,
      {
        email,
        password,
        returnSecureToken: true
      }
    );
    
    const { idToken, localId, refreshToken } = response.data;
    
    // جلب بيانات المستخدم من Firestore
    const userDoc = await admin.firestore().collection('users').doc(localId).get();
    const userData = userDoc.data();
    
    res.json({
      token: idToken,
      userId: localId,
      userData: userData
    });
    
  } catch (error) {
    res.status(401).json({ 
      error: error.response?.data?.error?.message || 'فشل تسجيل الدخول' 
    });
  }
});
```

**خيار 2: استخدام Custom Tokens**

```javascript
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  
  try {
    // 1. التحقق من كلمة المرور عبر Firebase REST API
    const firebaseApiKey = 'YOUR_FIREBASE_WEB_API_KEY';
    const authResponse = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${firebaseApiKey}`,
      { email, password, returnSecureToken: true }
    );
    
    const userId = authResponse.data.localId;
    
    // 2. إنشاء Custom Token
    const customToken = await admin.auth().createCustomToken(userId);
    
    // 3. جلب بيانات المستخدم
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    res.json({
      token: customToken,
      userId: userId,
      userData: userDoc.data()
    });
    
  } catch (error) {
    res.status(401).json({ error: 'بيانات الاعتماد غير صحيحة' });
  }
});
```

## 📋 خطوات الإصلاح على السيرفر

1. **احصل على Firebase Web API Key**:
   ```
   من ملف: lib/firebase_options.dart
   Android apiKey: AIzaSyCBtbz9yghaWWptueg1cr1QMhRZDvw1hrU
   ```

2. **عدّل ملف `routes/auth.js` (أو مكان تعريف `/login`)**

3. **أضف axios للمشروع**:
   ```bash
   npm install axios
   ```

4. **استبدل دالة `/login` بأحد الحلول المقترحة أعلاه**

5. **اختبر السيرفر**:
   ```powershell
   curl http://72.60.80.201:3001/api/auth/login -Method POST -ContentType "application/json" -Body '{"email":"test@test.com","password":"123456"}'
   ```

6. **بعد إصلاح السيرفر، عدّل التطبيق**:
   - أعد استخدام `ApiService.login()` بعد `signup`
   - احذف الكود المؤقت لحفظ البيانات في `signup`

## 🔍 التحقق من الإصلاح

بعد إصلاح السيرفر:

```powershell
# يجب أن يعطي 200 OK مع token و userData
curl http://72.60.80.201:3001/api/auth/login -Method POST `
  -ContentType "application/json" `
  -Body '{"email":"test@test.com","password":"123456"}'
```

## 📝 ملاحظات

- الحل الحالي في التطبيق **مؤقت** ويسمح بالتسجيل والاستخدام
- **يجب إصلاح السيرفر** لتفعيل تسجيل الدخول الكامل
- Token المؤقت المستخدم حالياً: `signup_{userId}`

---

**تاريخ**: 11 ديسمبر 2025  
**الحالة**: حل مؤقت مطبق، يحتاج إصلاح السيرفر
