# ✨ ميزة إدارة صلاحيات المشرفين

## 🎉 تم الإضافة!

الآن يمكنك **ترقية وتخفيض المستخدمين** مباشرة من داخل التطبيق!

---

## 📱 كيف تستخدمها:

### في تبويب "المستخدمين":

1. **افتح لوحة القيادة** → **تبويب المستخدمين**

2. **كل مستخدم يظهر مع زرين**:
   - 🟢 **زر الترقية/التخفيض** (أيقونة درع)
     - أخضر = ترقية لمشرف
     - أحمر = إزالة الإشراف
   
   - ⚫ **زر الحظر** (أيقونة دائرة/منع)
     - رمادي = حظر المستخدم
     - أحمر = إلغاء الحظر

3. **المشرفون يظهرون ب**:
   - أيقونة برتقالية 👑
   - شارة "مشرف" برتقالية
   - رمز `admin_panel_settings`

---

## 🔧 ما تم إضافته:

### 1. في التطبيق (`lib/services/api_service.dart`):
```dart
✅ دالة جديدة: toggleUserAdmin(userId, makeAdmin)
```

### 2. في واجهة المستخدمين (`lib/screens/admin_dashboard_screen.dart`):
```dart
✅ تصميم جديد للمستخدمين (Cards)
✅ أيقونة برتقالية للمشرفين
✅ شارة "مشرف"
✅ زرين لكل مستخدم (ترقية + حظر)
✅ حوارات تأكيد واضحة
✅ رسائل نجاح/فشل
```

### 3. على السيرفر (مطلوب إضافة):
```javascript
✅ POST /api/admin/users/:userId/admin
```

**الكود في**: [admin_endpoints_code.js](admin_endpoints_code.js)

---

## 🚀 لتفعيل الميزة كاملاً:

### الخطوة 1: أضف الـ endpoint على السيرفر

```bash
ssh root@72.60.80.201
cd ~/aqar-server
nano index.js
```

### الخطوة 2: أضف هذا الكود:

```javascript
// بعد endpoint /admin/users/:userId/ban
router.post('/admin/users/:userId/admin', adminOnly, async (req, res) => {
  try {
    const { userId } = req.params;
    const { isAdmin } = req.body;
    
    console.log(`👑 ${isAdmin ? 'Promoting' : 'Demoting'} user: ${userId}`);
    
    await db.collection('users').doc(userId).update({
      isAdmin: isAdmin === true,
    });
    
    console.log(`✅ User ${userId} admin status updated to: ${isAdmin}`);
    res.json({ success: true, isAdmin });
  } catch (error) {
    console.error('❌ Error updating user admin status:', error);
    res.status(500).json({ error: 'Failed to update user admin status' });
  }
});
```

### الخطوة 3: احفظ وأعد التشغيل:

```bash
# احفظ: Ctrl+O ثم Enter
# اخرج: Ctrl+X
pm2 restart all
```

### الخطوة 4: اختبر!

```bash
flutter run
```

---

## ✨ الميزات:

### ✅ لا حاجة لـ Firebase Console بعد الآن!
- المشرف الأول فقط يحتاج إعداد يدوي
- بعد ذلك، يمكن للمشرفين ترقية/تخفيض أي شخص

### ✅ واجهة واضحة:
- شارات ملونة للمشرفين
- رسائل تأكيد قبل أي إجراء
- إشعارات نجاح/فشل

### ✅ أمان:
- فقط المشرفون يمكنهم الوصول
- حوارات تأكيد لمنع الأخطاء
- رسائل خطأ واضحة

---

## 🎯 الاستخدام:

### لترقية مستخدم لمشرف:
1. اضغط الزر الأخضر (درع مع +)
2. أكد العملية
3. ✅ تم! المستخدم الآن مشرف

### لإزالة صلاحيات مشرف:
1. اضغط الزر الأحمر (درع مع -)
2. أكد العملية
3. ✅ تم! المستخدم الآن عادي

### لحظر مستخدم:
1. اضغط الزر الرمادي (دائرة)
2. أكد العملية
3. ✅ تم! المستخدم محظور

---

## 📊 ملخص:

| الميزة | الحالة | ملاحظات |
|--------|--------|---------|
| واجهة الترقية/التخفيض | ✅ جاهزة | في التطبيق |
| دالة API | ✅ جاهزة | في ApiService |
| Server endpoint | ⏳ مطلوب | أضفه من ملف admin_endpoints_code.js |

---

## 🎉 النتيجة:

بدلاً من الذهاب لـ Firebase Console كل مرة، الآن:
- ✅ أضف مشرفين من التطبيق مباشرة
- ✅ أزل صلاحيات المشرفين بنقرة واحدة
- ✅ احظر المستخدمين بسهولة
- ✅ كل شيء في مكان واحد!

**استمتع بالميزة الجديدة!** 🚀
