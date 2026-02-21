# 🚀 خطوات تفعيل Deep Links - إصلاح سريع

## ✅ التعديلات المنجزة:

1. ✅ تحديث `AndroidManifest.xml` لدعم الدومينات:
   - `n4yo.com`
   - `s313.store`
   - `www.n4yo.com`

2. ✅ إضافة `AppConstants.appDomain` للتحكم بالدومين المستخدم في المشاركة

3. ✅ تحديث رابط المشاركة ليستخدم الدومين من الإعدادات

---

## 🔧 الخطوات المطلوبة منك:

### 1️⃣ **رفع ملف assetlinks.json على السيرفر**

**يجب** رفع هذا الملف على كلا الدومينين:

#### 📂 المسار المطلوب:
```
https://n4yo.com/.well-known/assetlinks.json
https://s313.store/.well-known/assetlinks.json
```

#### 📝 محتوى الملف:
```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.shami313.aqar_app",
      "sha256_cert_fingerprints": [
        "73:EC:BD:4B:7C:C7:9A:73:55:DB:10:B5:9D:8A:14:07:C3:F9:B4:E4:FE:E5:ED:1F:6B:D8:84:71:7B:2C:55:E2"
      ]
    }
  }
]
```

#### 🔨 كيفية الرفع (عبر SSH):
```bash
# إنشاء المجلد
mkdir -p /var/www/html/.well-known

# إنشاء الملف
cat > /var/www/html/.well-known/assetlinks.json << 'EOF'
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.shami313.aqar_app",
      "sha256_cert_fingerprints": [
        "73:EC:BD:4B:7C:C7:9A:73:55:DB:10:B5:9D:8A:14:07:C3:F9:B4:E4:FE:E5:ED:1F:6B:D8:84:71:7B:2C:55:E2"
      ]
    }
  }
]
EOF

# ضبط الصلاحيات
chmod 644 /var/www/html/.well-known/assetlinks.json
```

---

### 2️⃣ **التحقق من الملف**

افتح الرابط في المتصفح وتأكد أن الملف يظهر:
```
https://n4yo.com/.well-known/assetlinks.json
https://s313.store/.well-known/assetlinks.json
```

**يجب أن يظهر محتوى JSON بدون أخطاء 404**

---

### 3️⃣ **إعادة بناء التطبيق**

```bash
flutter clean
flutter pub get
flutter build apk --release
```

---

### 4️⃣ **اختبار Deep Links**

#### الطريقة 1: عبر ADB
```bash
# تثبيت التطبيق
flutter install

# اختبار الرابط
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://n4yo.com/properties/PROPERTY_ID" \
  com.shami313.aqar_app
```

#### الطريقة 2: على الهاتف
1. أرسل رابط عقار لنفسك عبر واتساب
2. اضغط على الرابط
3. **يجب أن يفتح التطبيق مباشرة** ✅

---

## 🎯 تغيير الدومين المستخدم

إذا أردت تغيير الدومين من `n4yo.com` إلى `s313.store`:

**افتح:** `lib/config/app_constants.dart`

**غيّر السطر:**
```dart
static const String appDomain = 'n4yo.com'; 
```

**إلى:**
```dart
static const String appDomain = 's313.store';
```

---

## ❓ حل المشاكل الشائعة

### المشكلة: الرابط يفتح المتصفح بدلاً من التطبيق

**الحل:**
```bash
# امسح بيانات التطبيق
adb shell pm clear com.shami313.aqar_app

# أعد تثبيته
flutter install
```

---

### المشكلة: خطأ 404 عند فتح assetlinks.json

**تأكد من:**
1. ✅ الملف موجود في المسار الصحيح
2. ✅ الصلاحيات `644`
3. ✅ لا يوجد `.htaccess` يمنع الوصول للمجلد `.well-known`

---

## ✅ قائمة التحقق

- [ ] رفع `assetlinks.json` على `n4yo.com/.well-known/`
- [ ] رفع `assetlinks.json` على `s313.store/.well-known/`
- [ ] التحقق من الملفات في المتصفح
- [ ] `flutter clean && flutter build apk --release`
- [ ] اختبار الرابط على الهاتف

---

## 📞 الدعم

إذا استمرت المشكلة:
1. تأكد من البصمة SHA256 صحيحة
2. تحقق من logs عبر: `adb logcat | grep -i "deeplink\|intent"`
3. راجع الملف الكامل: `DEEP_LINKS_SETUP.md`
