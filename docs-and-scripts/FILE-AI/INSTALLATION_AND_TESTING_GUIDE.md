# 🚀 دليل التثبيت والاختبار - ميزة حذف مشاهدات الإعلانات

## ✅ ما تم الانتهاء منه

- ✅ 3 Endpoints جديدة في Backend (Node.js)
- ✅ 3 دوال API جديدة في Dart
- ✅ واجهة مستخدم متقدمة مع أزرار وحوارات
- ✅ معالجة أخطاء شاملة
- ✅ تسجيل (logging) مفصل

---

## 📦 خطوات التثبيت

### 1️⃣ التحقق من الملفات المعدلة

```bash
# تحقق من التعديلات في:
FILE-SSH/routes/admin.js          # ✅ جديد: 3 endpoints
lib/services/api_service.dart     # ✅ جديد: 3 دوال API
lib/screens/admin_dashboard_screen.dart  # ✅ جديد: UI + 3 دوال
```

### 2️⃣ إعادة تشغيل الخادم (Backend)

```bash
# إذا كنت تستخدم PM2
pm2 restart all

# أو إذا كنت تشغله محلياً
node server.js
```

### 3️⃣ إعادة تشغيل التطبيق (Frontend)

```bash
# إما عبر Hot Reload (إن أمكن) أو Hot Restart
# أو إعادة تجميع التطبيق كاملاً:

flutter clean
flutter pub get
flutter run
```

---

## 🧪 سيناريوهات الاختبار

### Test 1: حذف مشاهدة واحدة ✔️

**الخطوات:**
1. اذهب إلى Admin Dashboard → تبويب الإعدادات
2. مرر لأسفل إلى "مشاهدات الشريط"
3. ستجد قائمة المستخدمين الذين شاهدوا الإعلان
4. اضغط على الثلاث نقاط (⋮) بجانب أي مستخدم
5. اختر "حذف هذه المشاهدة"
6. تأكد من الحذف في الحوار

**النتيجة المتوقعة:**
- ✅ المشاهدة تختفي من القائمة
- ✅ يظهر رسالة نجاح (✅ تم حذف المشاهدة بنجاح)
- ✅ القائمة تحدث تلقائياً

---

### Test 2: حذف جميع مشاهدات المستخدم ✔️

**الخطوات:**
1. افتح Admin Dashboard
2. انتقل إلى قسم مشاهدات الشريط
3. اضغط على الثلاث نقاط (⋮)
4. اختر "حذف جميع مشاهدات المستخدم"
5. أكد الحذف

**النتيجة المتوقعة:**
- ✅ جميع مشاهدات هذا المستخدم تختفي
- ✅ رسالة: "✅ تم حذف X مشاهدة للمستخدم بنجاح"
- ✅ العدد في الأعلى ينقص

---

### Test 3: حذف جميع المشاهدات (Reset) 🔴

**الخطوات:**
1. اذهب إلى Admin Dashboard
2. في قسم مشاهدات الشريط، لاحظ الأيقونة الحمراء (🗑️) في الأعلى
3. اضغط عليها
4. حوار تحذيري يظهر مع صيغة مهددة
5. اضغط "حذف الكل"

**النتيجة المتوقعة:**
- 🔴 رسالة تحذير: "حذف جميع المشاهدات (xx مشاهدة)؟"
- ✅ جميع المشاهدات تُحذف
- ✅ القائمة تصبح فارغة
- ✅ رسالة: "✅ تم حذف XX مشاهدة بنجاح"

---

## 🔍 الاختبار عبر API (Postman/cURL)

### اختبار Endpoint 1: حذف مشاهدة واحدة

```bash
curl -X DELETE "http://localhost:3000/admin/announcement-views/doc_id_here" \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json"
```

**الاستجابة الناجحة:**
```json
{
  "message": "تم حذف المشاهدة بنجاح"
}
```

---

### اختبار Endpoint 2: حذف جميع المشاهدات

```bash
curl -X DELETE "http://localhost:3000/admin/announcement-views/bulk/all?announcementId=announcement_id_here" \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json"
```

**الاستجابة:**
```json
{
  "message": "تم حذف 15 مشاهدة بنجاح",
  "deletedCount": 15
}
```

---

### اختبار Endpoint 3: حذف مشاهدات مستخدم

```bash
curl -X DELETE "http://localhost:3000/admin/announcement-views/user/user_id_here?announcementId=announcement_id_here" \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json"
```

**الاستجابة:**
```json
{
  "message": "تم حذف مشاهدات المستخدم بنجاح",
  "deletedCount": 3
}
```

---

## 🐛 استكشاف الأخطاء

### المشكلة 1: لا تظهر الأزرار

**الحل:**
- ✅ تأكد من وجود مشاهدات (القائمة ليست فارغة)
- ✅ أعد تحميل الصفحة (F5)
- ✅ تحقق من console للأخطاء

### المشكلة 2: حوار التأكيد لا يظهر

**الحل:**
- ✅ تحقق من الـ context متاح
- ✅ تأكد من mounted = true
- ✅ جرب Hot Restart بدلاً من Hot Reload

### المشكلة 3: الحذف يفشل

**الحل:**
- ✅ تحقق من token صحيح
- ✅ تأكد من أن المستخدم مسؤول (admin)
- ✅ انظر إلى server logs
- ✅ تحقق من connection إلى Firestore

### المشكلة 4: لا يتم تحديث القائمة

**الحل:**
- ✅ تأكد من mounted = true قبل setState
- ✅ جرب إعادة تحميل يدوية (refresh icon)
- ✅ تحقق من الـ State lifecycle

---

## 📊 التحقق من البيانات في Firestore

```javascript
// قم بتشغيل هذا في Firebase Console:

db.collection('announcement_views')
  .where('announcementId', '==', 'your_announcement_id')
  .get()
  .then(snapshot => {
    console.log('عدد المشاهدات:', snapshot.size);
    snapshot.forEach(doc => {
      console.log(doc.data());
    });
  });
```

---

## 📝 Logger Output (في Server Console)

### عند حذف ناجح:
```
✅ [DELETE-VIEW] تم حذف المشاهدة: doc_id_here
✅ [DELETE-USER-VIEWS] تم حذف 3 مشاهدة للمستخدم xxx من الإعلان yyy
✅ [DELETE-ALL-VIEWS] تم حذف 25 مشاهدة للإعلان: yyy
```

### عند خطأ:
```
❌ Error deleting view: [error details]
⚠️ [DELETE-VIEW] Missing viewId parameter
```

---

## 🎯 Checklist قبل الإطلاق

- [ ] تم تعديل `admin.js` بـ 3 endpoints
- [ ] تم تعديل `api_service.dart` بـ 3 دوال
- [ ] تم تعديل `admin_dashboard_screen.dart` بـ UI + دوال
- [ ] تم اختبار حذف مشاهدة واحدة
- [ ] تم اختبار حذف مشاهدات المستخدم
- [ ] تم اختبار حذف جميع المشاهدات
- [ ] تم التحقق من Firestore بحذف البيانات
- [ ] لا توجد أخطاء في console
- [ ] رسائل الخطأ واضحة للمستخدم
- [ ] الأداء مقبول (لا توجد تأخيرات)

---

## 🔄 الإصدار والنشر

### للاختبار المحلي:
```bash
# Backend
npm start

# Frontend
flutter run
```

### للنشر في الإنتاج:
```bash
# تحديث Backend
git add -A
git commit -m "✨ إضافة ميزة حذف مشاهدات الإعلانات"
git push

# تجميع Android/iOS
flutter build apk  # أو ipa للـ iOS
```

---

## 💬 الدعم والمساعدة

إذا واجهت أي مشاكل:

1. تحقق من Logs في Console (browser + server)
2. تأكد من صحة التوكن والصلاحيات
3. تحقق من اتصال Firestore
4. جرب إعادة تشغيل التطبيق

---

## ✅ تم الإنجاز!

**الميزة الجديدة اليست جاهزة للاستخدام المباشر!** 🎉

استمتع بإدارة مشاهدات الإعلانات بكل سهولة!
