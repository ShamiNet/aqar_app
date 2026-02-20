# إصلاح أيقونات الخريطة - تحديث propertyType

## المشكلة
كانت جميع العقارات تظهر بأيقونة marker افتراضية على الخريطة لأن السيرفر لم يكن يرسل حقل `propertyType`.

## الحل المطبق

### 1. تحديث السيرفر
✅ إضافة حقل `propertyType` إلى:
- عند إضافة عقار جديد (`POST /api/properties`)
- يتم حفظه في قاعدة بيانات Firebase

### 2. تحديث التطبيق
✅ تعديل الملفات التالية:
- ✅ `lib/services/api_service.dart` - إضافة معامل propertyType
- ✅ `lib/controllers/add_property_controller.dart` - إرسال selectedType
- ✅ `lib/screens/properties_map_screen.dart` - معالجة العقارات القديمة
- ✅ `lib/screens/add_property_screen.dart` - توحيد الأنواع
- ✅ `lib/controllers/add_property_controller.dart` - توحيد القيم الافتراضية

### 3. معالجة العقارات القديمة
✅ في الخريطة، إذا لم يكن `propertyType` موجوداً:
- يتم استنتاج النوع من العنوان
- أو استخدام "بيت" كقيمة افتراضية

## خطوات التطبيق

### الخطوة 1: إعادة تشغيل السيرفر
```bash
cd FILE-SSH
pm2 restart index
# أو
node index.js
```

### الخطوة 2: تحديث العقارات القديمة في Firebase (اختياري)
لتحديث جميع العقارات الموجودة في قاعدة البيانات بإضافة propertyType:

```bash
cd FILE-SSH
node update_property_types.js
```

**ملاحظة:** هذا الـ script:
- يقرأ جميع العقارات من Firebase
- يستنتج نوع العقار من العنوان
- يحدّث قاعدة البيانات
- **يجب تشغيله مرة واحدة فقط**

### الخطوة 3: إعادة تشغيل التطبيق
```bash
flutter clean
flutter pub get
flutter run
```

## أنواع العقارات المدعومة

| النوع   | الأيقونة              | للبيع           | للإيجار         |
|---------|----------------------|-----------------|-----------------|
| بيت     | `Icons.house_rounded`| 🔴 أحمر         | 🔵 أزرق         |
| فيلا    | `Icons.villa_rounded`| 🔴 أحمر         | 🔵 أزرق         |
| بناية   | `Icons.apartment_rounded`| 🔴 أحمر     | 🔵 أزرق         |
| ارض     | `Icons.landscape_rounded`| 🔴 أحمر     | 🔵 أزرق         |
| دكان    | `Icons.store_rounded`| 🔴 أحمر         | 🔵 أزرق         |

## التحقق من النجاح

بعد التطبيق:
1. ✅ العقارات الجديدة ستظهر بأيقونات مخصصة على الخريطة
2. ✅ العقارات القديمة ستظهر بأيقونات مستنتجة من العنوان
3. ✅ الألوان تطابق الفئة (بيع = أحمر، إيجار = أزرق)

## ملفات تم تعديلها

### Frontend (Flutter)
- `lib/services/api_service.dart`
- `lib/controllers/add_property_controller.dart`
- `lib/screens/properties_map_screen.dart`
- `lib/screens/add_property_screen.dart`

### Backend (Node.js)
- `FILE-SSH/routes/properties.js`
- `FILE-SSH/update_property_types.js` *(جديد)*

## استكشاف الأخطاء

### المشكلة: لا تزال العقارات تظهر بأيقونة marker
**الحل:**
1. تأكد من إعادة تشغيل السيرفر
2. جرب إضافة عقار جديد وتحقق من ظهوره على الخريطة
3. شغّل script التحديث للعقارات القديمة

### المشكلة: الأيقونات بلون خاطئ
**الحل:**
1. تحقق من حقل `category` (يجب أن يكون "بيع" أو "إيجار")
2. راجع دالة `getColorForCategory()` في [properties_map_screen.dart](lib/screens/properties_map_screen.dart)

### المشكلة: بعض العقارات بأيقونة خاطئة
**الحل:**
1. افتح تفاصيل العقار وعدّله
2. اختر النوع الصحيح من القائمة
3. احفظ التعديلات

## ملاحظات إضافية

- ✅ التطبيق يدعم الآن 5 أنواع رسمية للعقارات
- ✅ العقارات القديمة محمية من الأخطاء بفضل الاستنتاج التلقائي
- ✅ جميع التعديلات متوافقة مع الكود الموجود
