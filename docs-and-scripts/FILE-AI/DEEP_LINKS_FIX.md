# إصلاح مشكلة Deep Links

## المشاكل التي تم إصلاحها:

### 1. عدم تطابق النطاقات (Domain Mismatch)
- **المشكلة**: كان AndroidManifest.xml يحتوي على `aqar-app.com` بينما الكود يستخدم `n4yo.com`
- **الحل**: تم تحديث AndroidManifest.xml ليستخدم `n4yo.com`

### 2. صفحة الويب الافتراضية
- **المشكلة**: ملف index.html كان يعرض صفحة Firebase الافتراضية
- **الحل**: تم إنشاء صفحة مخصصة تحاول فتح التطبيق تلقائياً وتوفر رابط تحميل

### 3. معالج الروابط العميقة
- **التحسين**: تم إضافة logs أكثر تفصيلاً لتتبع الروابط

## خطوات النشر:

### 1. نشر التغييرات على Firebase Hosting:
```bash
firebase deploy --only hosting
```

### 2. إعادة بناء التطبيق Android:
```bash
flutter clean
flutter pub get
flutter build apk --release
# أو للـ bundle:
flutter build appbundle --release
```

### 3. التحقق من assetlinks.json:
تأكد من أن الملف متاح على:
```
https://n4yo.com/.well-known/assetlinks.json
```

### 4. اختبار الروابط:

#### اختبار عبر ADB:
```bash
# اختبار Custom Scheme
adb shell am start -a android.intent.action.VIEW -d "aqarapp://property/ehUXfWZm7bSMNbcjLjvJ" com.shami313.aqar_app

# اختبار HTTPS Deep Link
adb shell am start -a android.intent.action.VIEW -d "https://n4yo.com/property/ehUXfWZm7bSMNbcjLjvJ" com.shami313.aqar_app
```

#### اختبار عبر المتصفح:
1. افتح الرابط في Chrome على الجوال: `https://n4yo.com/property/ehUXfWZm7bSMNbcjLjvJ`
2. يجب أن تظهر رسالة تطلب فتح التطبيق
3. إذا لم تظهر، اضغط على زر "تحميل التطبيق"

## ملاحظات مهمة:

### التحقق من SHA-256 Fingerprint:
تأكد من أن البصمة في `assetlinks.json` صحيحة:
```bash
# للحصول على بصمة Release:
keytool -list -v -keystore /path/to/your/keystore.jks -alias your-key-alias

# للحصول على بصمة Debug:
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### التحقق من App Links في Android:
بعد تثبيت التطبيق، يمكنك التحقق من App Links:
```bash
adb shell pm get-app-links com.shami313.aqar_app
```

### مشاكل محتملة وحلولها:

1. **الرابط يفتح المتصفح بدلاً من التطبيق**
   - تأكد من أن `android:autoVerify="true"` موجود في intent-filter
   - تأكد من أن assetlinks.json متاح ويحتوي على البصمة الصحيحة
   - جرب إلغاء تثبيت وإعادة تثبيت التطبيق

2. **الرابط لا يفعل شيء**
   - تحقق من logs في Android Studio
   - تأكد من أن main.dart يحتوي على معالج الروابط
   - تأكد من أن app_links package مثبت

3. **صفحة الويب تظهر بدلاً من فتح التطبيق**
   - هذا طبيعي للمستخدمين الذين ليس لديهم التطبيق
   - الصفحة الآن توفر زر تحميل وتحاول فتح التطبيق تلقائياً

## الملفات المعدلة:

1. `android/app/src/main/AndroidManifest.xml` - تحديث النطاق إلى n4yo.com
2. `public/index.html` - صفحة ويب مخصصة مع Auto-redirect
3. `lib/main.dart` - تحسين logs لمعالج الروابط
4. `public/.well-known/assetlinks.json` - موجود مسبقاً (تم التحقق منه)
5. `public/.well-known/apple-app-site-association` - تم إنشاؤه لـ iOS
