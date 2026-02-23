# 🔗 إعداد Deep Links للتطبيق

## ✅ التعديلات المنفذة:

### 1. AndroidManifest.xml
تم إضافة دعم لثلاثة دومينات:
- ✅ `n4yo.com`
- ✅ `s313.store`
- ✅ `www.n4yo.com`

---

## 📋 الخطوات المطلوبة:

### 1. رفع ملف assetlinks.json على السيرفر

يجب رفع الملف التالي على **كلا الدومينين**:

#### 📁 للدومين `n4yo.com`:
```
https://n4yo.com/.well-known/assetlinks.json
```

#### 📁 للدومين `s313.store`:
```
https://s313.store/.well-known/assetlinks.json
```

**محتوى الملف** (نفس المحتوى لكلا الدومينين):
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

---

### 2. كيفية رفع الملف على السيرفر:

#### الطريقة 1: عبر SSH
```bash
# الاتصال بالسيرفر
ssh your-user@s313.store

# إنشاء المجلد
mkdir -p /var/www/html/.well-known

# رفع الملف
nano /var/www/html/.well-known/assetlinks.json
# (الصق المحتوى أعلاه واحفظ)

# ضبط الصلاحيات
chmod 644 /var/www/html/.well-known/assetlinks.json
```

#### الطريقة 2: عبر cPanel/FTP
1. افتح مدير الملفات في cPanel
2. انتقل إلى المجلد الرئيسي للموقع (public_html أو www)
3. أنشئ مجلد اسمه `.well-known`
4. داخله أنشئ ملف `assetlinks.json`
5. الصق المحتوى أعلاه

---

### 3. التحقق من التثبيت:

#### اختبر الروابط التالية في المتصفح:

✅ **للدومين n4yo.com:**
```
https://n4yo.com/.well-known/assetlinks.json
```

✅ **للدومين s313.store:**
```
https://s313.store/.well-known/assetlinks.json
```

**يجب أن تظهر نفس محتوى JSON بدون أخطاء**

---

### 4. إعادة بناء التطبيق:

بعد رفع الملفات، أعد بناء التطبيق:

```bash
# تنظيف
flutter clean

# إعادة البناء
flutter build apk --release

# أو للـ App Bundle
flutter build appbundle --release
```

---

### 5. اختبار Deep Links:

#### **الاختبار عبر ADB:**

```bash
# اختبار n4yo.com
adb shell am start -W -a android.intent.action.VIEW -d "https://n4yo.com/properties/PROPERTY_ID" com.shami313.aqar_app

# اختبار s313.store
adb shell am start -W -a android.intent.action.VIEW -d "https://s313.store/properties/PROPERTY_ID" com.shami313.aqar_app

# اختبار custom scheme
adb shell am start -W -a android.intent.action.VIEW -d "aqarapp://properties/PROPERTY_ID" com.shami313.aqar_app
```

#### **الاختبار على الهاتف:**
1. أرسل رابط عبر واتساب أو رسالة نصية
2. اضغط على الرابط
3. يجب أن يفتح التطبيق مباشرة (إذا كان مثبتاً)

---

## 🔧 حل المشاكل:

### المشكلة 1: الرابط يفتح في المتصفح بدلاً من التطبيق

**الحل:**
```bash
# امسح بيانات التطبيق
adb shell pm clear com.shami313.aqar_app

# أعد تثبيت التطبيق
flutter install
```

---

### المشكلة 2: خطأ في assetlinks.json

تأكد من:
- ✅ الملف متاح على `https://DOMAIN/.well-known/assetlinks.json`
- ✅ content-type: `application/json`
- ✅ لا توجد أخطاء في صيغة JSON
- ✅ البصمة (SHA256) صحيحة

---

### المشكلة 3: الحصول على البصمة الصحيحة

```bash
# للإصدار debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# للإصدار release
keytool -list -v -keystore /path/to/your/keystore.jks -alias your-alias
```

ابحث عن السطر الذي يبدأ بـ `SHA256:` وانسخ البصمة بصيغة hex (مع علامات :)

---

## 📝 ملاحظات مهمة:

1. ⚠️ **Android 12+**: يجب أن يكون `android:autoVerify="true"` موجوداً
2. ⚠️ **HTTPS فقط**: Deep Links تعمل مع HTTPS (ليس HTTP)
3. ⚠️ **التثبيت الأول**: قد يستغرق Android بعض الوقت للتحقق من الروابط
4. ⚠️ **التحديثات**: بعد كل تحديث للتطبيق، قد تحتاج لإعادة تعيين إعدادات الروابط

---

## ✅ قائمة التحقق النهائية:

- [ ] ملف `assetlinks.json` موجود على `n4yo.com/.well-known/assetlinks.json`
- [ ] ملف `assetlinks.json` موجود على `s313.store/.well-known/assetlinks.json`
- [ ] الروابط تفتح بشكل صحيح في المتصفح
- [ ] البصمة SHA256 صحيحة في الملف
- [ ] تم إعادة بناء التطبيق
- [ ] تم اختبار الروابط على جهاز حقيقي
- [ ] التطبيق يفتح عند النقر على الروابط

---

## 🎯 النتيجة المتوقعة:

بعد تطبيق جميع الخطوات:
- ✅ روابط `n4yo.com/properties/ID` تفتح التطبيق
- ✅ روابط `s313.store/properties/ID` تفتح التطبيق
- ✅ روابط `aqarapp://properties/ID` تفتح التطبيق
- ✅ المشاركة عبر واتساب/تلغرام تعمل بشكل صحيح
