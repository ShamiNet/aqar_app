// مسار الملف: lib/config/app_constants.dart

class AppConstants {
  // ==========================================
  // 🌐 إعدادات الخادم والشبكة (API & Network)
  // ==========================================
  // ✅ تم تحويل الرابط إلى HTTPS الآمن
  static const String baseUrl = 'https://s313.store/api';

  // ✅ دومين Deep Links (للمشاركة وفتح الروابط)
  static const String appDomain = 's313.store';
  static const String appUrl = 'https://$appDomain';

  static const String currentAppVersion = '1.0.0';

  // ==========================================
  // ⏱️ إعدادات الوقت والتخزين المؤقت (Timeouts & Cache)
  // ==========================================
  static const Duration defaultTimeout = Duration(seconds: 15);
  static const Duration longTimeout = Duration(seconds: 30);
  static const Duration cacheDuration = Duration(
    minutes: 5,
  ); // مدة الكاش المحلي

  // ==========================================
  // 🔑 مفاتيح التخزين المحلي (Shared Preferences Keys)
  // ==========================================
  static const String prefAuthToken = 'auth_token';
  static const String prefRefreshToken = 'refresh_token';
  static const String prefTokenExpiry = 'auth_token_expiry';
  static const String prefUserId = 'user_id';
  static const String prefUserEmail = 'user_email';
  static const String prefUserData = 'user_data';

  // مفاتيح الكاش (Cache Keys)
  static const String cachePropertiesBaseKey = 'cache_properties';
  static const String cachePropertyDetailBaseKey = 'cache_property_';

  // ==========================================
  // 📄 إعدادات الترقيم والتحميل (Pagination)
  // ==========================================
  static const int defaultPaginationLimit = 50;
  static const int paginationThreshold =
      200; // المسافة بالبكسل قبل نهاية القائمة لجلب المزيد
}
