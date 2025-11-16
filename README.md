# aqar_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## مفاتيح Google Directions API

يستخدم التطبيق خدمة رسم المسار (Directions API) في شاشة الخريطة.

### الطريقتان المتاحتان للمفتاح
1. ملف `dart_defines.json` (مفضل وأكثر أماناً):
	 - يوجد ملف `dart_defines.json` (مستثنى من Git) يحتوي:
		 ```json
		 { "GOOGLE_MAPS_DIRECTIONS_API_KEY": "YOUR_DIRECTIONS_KEY" }
		 ```
	 - تشغيل التطوير:
		 ```bash
		 flutter run --dart-define-from-file=dart_defines.json
		 ```
	 - بناء الإصدار:
		 ```bash
		 flutter build apk --release --dart-define-from-file=dart_defines.json
		 ```
2. قيمة ثابتة (fallback) داخل `properties_map_screen.dart` عبر `defaultValue` في:
	 ```dart
	 const kDirectionsKey = String.fromEnvironment(
		 'GOOGLE_MAPS_DIRECTIONS_API_KEY',
		 defaultValue: 'HARDCODED_KEY',
	 );
	 ```
	 عند عدم تمرير `--dart-define` سيُستخدم المفتاح الثابت.

### تفعيل الخدمة
1. فعل "Directions API" من Google Cloud Console.
2. أنشئ مفتاحاً جديداً ثم:
	 - Application restrictions: None (للاختبار) أو قصره لاحقاً حسب الحاجة.
	 - API restrictions: اختر Directions API فقط.
3. تأكد من تفعيل الفوترة Billing.

### أفضل الممارسات الأمنية
- لا ترفع المفتاح الثابت الحقيقي إلى مستودع عام؛ استبدله بقيمة وهمية.
- استخدم مفتاح منفصل لـ Maps SDK (مقيّد بالحزمة و SHA‑1) وآخر لـ Directions.
- يمكن نقل استدعاء Directions إلى خادم وسيط لتخفيف كشف المفتاح.

### Logs مفيدة
- عند استخدام المفتاح من `--dart-define`: يظهر في السجل:
	`Using dart-define Directions API key.`
- إن لم يُمرر المتغيّر: يظهر:
	`GOOGLE_MAPS_DIRECTIONS_API_KEY missing; falling back...`

### English Summary
Two ways to provide the Directions API key:
1. `dart_defines.json` (recommended) with `flutter run --dart-define-from-file=dart_defines.json`.
2. Hardcoded default in `properties_map_screen.dart` (fallback, less secure).
Secure the key by restricting it to the Directions API and avoid committing real keys publicly.
