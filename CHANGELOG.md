# Changelog

All notable changes to Aqar Plus (عقار بلص) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-12

### Added - الميزات الجديدة

#### تطبيق Flutter الأساسي
- تطبيق عقارات متكامل باللغة العربية
- واجهة مستخدم حديثة وسلسة مع دعم الثيمات
- نظام مصادقة كامل باستخدام Firebase Authentication
  - تسجيل الدخول بالبريد الإلكتروني وكلمة المرور
  - تسجيل الدخول عبر Google
  - إدارة الجلسات والحسابات

#### إدارة العقارات
- عرض العقارات بتصميم بطاقات احترافي مع مسافات واضحة
- تحسين ألوان العناوين لظهور أوضح
- صفحة تفاصيل العقار مع معلومات شاملة
- دعم الصور المتعددة مع عارض صور متقدم (Photo Viewer)
- دعم الفيديو مع مشغل فيديو (Video Player & Chewie)
- نظام التقييمات والمراجعات (Rating System)
- معالجة أسماء المستخدمين الطويلة بشكل صحيح
- جعل اسم المعلن قابلاً للنقر للانتقال إلى صفحة البروفايل

#### نظام الخرائط
- دمج Google Maps مع إمكانية عرض موقع العقار
- رسم المسار باستخدام Google Directions API
- تحديد الموقع الحالي باستخدام Geolocator
- دعم Geocoding للحصول على العناوين من الإحداثيات
- Polyline Points لرسم المسارات على الخريطة

#### لوحة تحكم الإدارة
- لوحة تحكم شاملة للمديرين
- إدارة المستخدمين والعقارات
- نظام صلاحيات متقدم
- إحصائيات ومراقبة البيانات
- واجهة تحليلات Firebase Analytics

#### الملف الشخصي والإعدادات
- صفحة بروفايل شخصي كامل
- صفحة بروفايل عام قابلة للمشاركة
- تعديل معلومات المستخدم
- رفع وتحديث صورة البروفايل
- عرض تاريخ الانضمام بشكل صحيح
- نظام المفضلة والعقارات المحفوظة

#### التواصل والمشاركة
- مشاركة العقارات عبر وسائل التواصل الاجتماعي (Share Plus)
- فتح روابط خارجية (URL Launcher)
- دعم Deep Links للانتقال المباشر داخل التطبيق
- دعم App Links
- نظام الإشعارات Firebase Cloud Messaging
- إشعارات محلية (Local Notifications)

#### البنية التحتية الخلفية
- Firebase Core للخدمات الأساسية
- Cloud Firestore لقاعدة البيانات
- Firebase Storage لتخزين الملفات
- Firebase App Check للأمان
- دمج Cloudinary لإدارة الصور
- نظام مراقبة في الوقت الفعلي للعقارات الجديدة

#### البوت الآلي ونظام النشر
- بوت Python (noteShami.py) لمراقبة العقارات الجديدة
- نشر تلقائي على Telegram (@aqarShami)
- دعم النشر على WhatsApp عبر Evolution API
- تنسيق رسائل احترافي مع Deep Links
- نظام خدمة Systemd (aqar_new.service)
- أدوات مساعدة متقدمة:
  - `get_qr.py` - استخراج QR Code
  - `test_evolution.py` - اختبارات شاملة
  - `setup_whatsapp.sh` - أداة إعداد تفاعلية

#### التصميم وتجربة المستخدم
- استخدام Google Fonts للخطوط
- نظام ثيمات متقدم مع Flex Color Scheme
- شريط تنقل منحني (Curved Navigation Bar)
- رسوم متحركة سلسة مع Flutter Animate
- Shimmer Effect أثناء التحميل
- Cached Network Images لتحسين الأداء
- نظام Carousel لعرض الصور

#### الواجهات والنماذج
- نماذج متقدمة مع Form Builder
- التحقق من صحة البيانات (Form Validators)
- حقول إضافية متقدمة (Extra Fields)
- واجهة تسجيل دخول احترافية (Flutter Login)
- قائمة جانبية متحركة (Zoom Drawer)

#### قسم "حول التطبيق"
- معلومات التطبيق والإصدار
- قناة التطبيق على Telegram: https://t.me/+yj3zSKtT_mYyZmU0
- التواصل مع المطور:
  - Telegram: @DevDrond (https://t.me/DevDrond)
  - الهاتف: +963991260012
- تحسين فتح الروابط الخارجية على Android

#### الدعم متعدد المنصات
- Android
- iOS
- Web
- Windows
- macOS
- Linux

### Enhanced - التحسينات
- تحسين مظهر بطاقات العقارات
- معالجة عرض النصوص الطويلة
- تحسين أداء تحميل الصور
- تحسين استجابة الواجهات
- تحسين فتح الروابط الخارجية باستخدام `launchUrl` بوضع `externalApplication`

### Technical - التقنيات المستخدمة
- Flutter SDK 3.9.0+
- Firebase Suite (Auth, Firestore, Storage, Analytics, Messaging, App Check)
- Google Maps Flutter
- Evolution API v2 (للواتساب)
- Docker & Docker Compose
- Python 3 مع firebase-admin
- Systemd للخدمات الخلفية
- VPS with Debian

### Documentation - التوثيق
- دليل الإعداد السريع (QUICKSTART.md)
- دليل استكشاف الأخطاء (TROUBLESHOOTING.md)
- دليل إعداد WhatsApp (WHATSAPP_SETUP.md)
- دليل إعداد Node.js (NODEJS_SETUP.md)
- ورقة الأوامر السريعة (CHEATSHEET.md)
- توثيق البوت (BOT_README.md)
- ملخص حالة المشروع (PROJECT_STATUS.md)
- أفضل الممارسات (BEST_PRACTICES_DATA_LOADING.md)
- سكريبتات النقل للسيرفر

### Security - الأمان
- Firebase App Check للحماية من إساءة الاستخدام
- مفاتيح API محمية
- نظام صلاحيات المسؤولين
- تشفير البيانات في Firebase
- استخدام dart-define للمفاتيح السرية

### Performance - الأداء
- Cached Network Images
- Shimmer Loading Effects
- تحميل البيانات بالصفحات (Pagination)
- تحسين استعلامات Firestore
- WebSocket للتواصل الفوري

[1.0.0]: https://github.com/ShamiNet/aqar_app/releases/tag/v1.0.0
