# 🔍 دليل استكشاف الأخطاء - مشكلة التسجيل

## ❌ الخطأ الحالي

```
Exception: API key not valid. Please pass a valid API key.
```

## 🔎 التحليل

هذا الخطأ يأتي من **Firebase Auth** وليس من تطبيق Flutter مباشرة. المشكلة على جانب **السيرفر** (Node.js).

### الأسباب المحتملة:

1. **مشكلة في Firebase Admin SDK على السيرفر**
   - ملف `serviceAccountKey.json` غير موجود أو غير صحيح
   - Firebase Admin لم يتم تهيئته بشكل صحيح
   - API Key منتهي الصلاحية أو محظور

2. **مشكلة في إعدادات Firebase Project**
   - المشروع محذوف أو معطل
   - الفوترة غير مفعلة
   - Firebase Auth غير مفعل في Console

3. **مشكلة في السيرفر**
   - السيرفر لا يعمل على `http://72.60.80.201:3001`
   - خطأ في كود السيرفر عند إنشاء المستخدمين

## ✅ خطوات الحل

### 1️⃣ فحص السيرفر

تحقق أن السيرفر يعمل:

```bash
curl http://72.60.80.201:3001/api/auth/signup -X POST -H "Content-Type: application/json" -d "{\"email\":\"test@test.com\",\"password\":\"123456\",\"username\":\"test\",\"phone\":\"\"}"
```

### 2️⃣ فحص Firebase Console

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. افتح مشروع `aqar-app-aca19`
3. تحقق من:
   - ✅ Authentication مفعل
   - ✅ Email/Password Provider مفعل
   - ✅ المشروع ليس معطلاً

### 3️⃣ فحص Service Account Key

على السيرفر، تحقق من:

```bash
# تأكد أن الملف موجود
ls -la serviceAccountKey.json

# تأكد أنه JSON صالح
cat serviceAccountKey.json | jq .
```

### 4️⃣ فحص كود السيرفر

تأكد من تهيئة Firebase Admin بشكل صحيح:

```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
```

### 5️⃣ التحقق من Logs السيرفر

شغّل السيرفر وشاهد الـ logs:

```bash
# إذا كان Node.js
npm start

# أو
node server.js

# شاهد الأخطاء
```

## 🛠️ الإصلاحات المطبقة

### ✅ إضافة Detailed Logging

تم إضافة logging مفصل في `api_service.dart`:

```dart
// في signup()
debugPrint('🌐 [API] Sending signup request...');
debugPrint('📥 [API] Response status: ${response.statusCode}');
debugPrint('📥 [API] Response body: ${response.body}');
```

الآن يمكنك رؤية:
- URL الطلب
- البيانات المرسلة
- Response Code
- رسالة الخطأ الكاملة من السيرفر

## 📋 معلومات إضافية للتشخيص

بعد إعادة تشغيل التطبيق، ابحث في الـ Console عن:

```
🌐 [API] Sending signup request to: ...
📧 [API] Email: ...
📥 [API] Response status: ...
📥 [API] Response body: ...
```

هذه المعلومات ستساعد في تحديد:
- هل الطلب يصل للسيرفر؟
- ما هو status code الفعلي؟
- ما هي رسالة الخطأ الكاملة من السيرفر؟

## 🔧 حلول بديلة

### الحل 1: استخدام Firebase Auth مباشرة (مؤقت)

إذا كانت المشكلة في السيرفر، يمكن تعديل الكود ليستخدم Firebase Auth مباشرة:

```dart
import 'package:firebase_auth/firebase_auth.dart';

// في signup
final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: email,
  password: password,
);

// حفظ بيانات إضافية في Firestore
```

### الحل 2: إصلاح السيرفر

تأكد من أن السيرفر يستخدم Firebase Admin SDK بشكل صحيح:

```javascript
// routes/auth.js
router.post('/signup', async (req, res) => {
  try {
    const { email, password, username, phone } = req.body;
    
    // إنشاء المستخدم في Firebase Auth
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: username
    });
    
    // حفظ البيانات الإضافية في Firestore
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      username,
      phone,
      email,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.status(201).json({ success: true, userId: userRecord.uid });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(400).json({ error: error.message });
  }
});
```

## 📞 الخطوات التالية

1. **أعد تشغيل التطبيق** وحاول التسجيل مرة أخرى
2. **انسخ كل الـ logs** من Console (ابحث عن `[API]`)
3. **شارك الـ logs** لتحليل المشكلة بدقة
4. **تحقق من السيرفر** أنه يعمل ويستقبل الطلبات

---

**تاريخ**: 11 ديسمبر 2025  
**الحالة**: قيد التشخيص
