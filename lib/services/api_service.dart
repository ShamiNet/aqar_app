import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:aqar_app/services/local_db_service.dart'; // ✅ استيراد ملف قواعد البيانات المحلية

// ✅ استيراد ملفات الإعدادات والخدمات
import 'package:aqar_app/config/app_constants.dart';
import 'package:aqar_app/config/cloudinary_config.dart';
import 'websocket_service.dart';

class ApiService {
  static const Duration _refreshSkew = Duration(seconds: 60);
  static Future<String?>? _refreshFuture;
  static VoidCallback? onTokenExpired;

  // =========================================================================
  // 🔄 مقارنة الإصدارات (Version Check)
  // =========================================================================
  static int compareVersions(String v1, String v2) {
    try {
      final version1 = v1.split('.').map(int.parse).toList();
      final version2 = v2.split('.').map(int.parse).toList();
      while (version1.length < version2.length) version1.add(0);
      while (version2.length < version1.length) version2.add(0);
      for (int i = 0; i < version1.length; i++) {
        if (version1[i] < version2[i]) return -1;
        if (version1[i] > version2[i]) return 1;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static bool isUpdateRequired(String minRequiredVersion) {
    return compareVersions(AppConstants.currentAppVersion, minRequiredVersion) <
        0;
  }

  // =========================================================================
  // 🧠 العقل المدبر: مرسل الطلبات الذكي
  // =========================================================================
  static Future<http.Response> _sendRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = await _ensureValidToken(prefs);

    // ✅ استخدام الرابط الأساسي من ملف الثوابت
    final uri = Uri.parse(
      endpoint.startsWith('http')
          ? endpoint
          : '${AppConstants.baseUrl}$endpoint',
    );

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      http.Response response = await _performHttpRequest(
        method,
        uri,
        headers,
        body,
      );

      if (response.statusCode == 401) {
        debugPrint('⚠️ [API] 401 Detected! Attempting to refresh token...');
        final newToken = await _refreshTokenThrottled();
        if (newToken != null) {
          headers['Authorization'] = 'Bearer $newToken';
          return await _performHttpRequest(method, uri, headers, body);
        } else {
          if (onTokenExpired != null) onTokenExpired!();
          return response;
        }
      }
      return response;
    } catch (e) {
      debugPrint('💥 [API] Network Error ($endpoint): $e');
      rethrow;
    }
  }

  static Future<http.Response> _performHttpRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    dynamic body,
  ) {
    // ✅ استخدام مهلة الاتصال من ملف الثوابت
    switch (method) {
      case 'POST':
        return http
            .post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(AppConstants.defaultTimeout);
      case 'PUT':
        return http
            .put(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(AppConstants.defaultTimeout);
      case 'DELETE':
        return http
            .delete(uri, headers: headers)
            .timeout(AppConstants.defaultTimeout);
      case 'GET':
      default:
        return http
            .get(uri, headers: headers)
            .timeout(AppConstants.defaultTimeout);
    }
  }

  // =========================================================================
  // 🔐 المصادقة (Auth)
  // =========================================================================
  static Future<void> loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          )
          .timeout(AppConstants.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await _saveAuthData(
          prefs,
          token: data['token'],
          refreshToken: data['refreshToken'],
          expiresInSeconds: _parseExpiry(data['expiresIn']),
        );
        // ✅ استخدام المفاتيح المركزية
        if (data['userId'] != null)
          await prefs.setString(AppConstants.prefUserId, data['userId']);
        if (data['email'] != null)
          await prefs.setString(AppConstants.prefUserEmail, data['email']);
        if (data['userData'] != null)
          await prefs.setString(
            AppConstants.prefUserData,
            jsonEncode(data['userData']),
          );
      } else {
        throw Exception('فشل تسجيل الدخول عبر جوجل');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(AppConstants.defaultTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      if (data['userData'] != null && data['userData']['isBanned'] == true) {
        throw Exception('هذا الحساب محظور');
      }
      await _saveAuthData(
        prefs,
        token: data['token'],
        refreshToken: data['refreshToken'] ?? '',
        expiresInSeconds: _parseExpiry(data['expiresIn']),
      );
      // ✅ استخدام المفاتيح المركزية
      await prefs.setString(AppConstants.prefUserId, data['userId']);
      await prefs.setString(AppConstants.prefUserEmail, email);
      if (data['userData'] != null)
        await prefs.setString(
          AppConstants.prefUserData,
          jsonEncode(data['userData']),
        );
    } else {
      throw Exception('فشل تسجيل الدخول');
    }
  }

  static Future<void> signup(
    String email,
    String password,
    String username,
    String phone, {
    String role = 'user',
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/auth/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'username': username,
            'phone': phone,
            'role': role,
          }),
        )
        .timeout(AppConstants.defaultTimeout);

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('فشل إنشاء الحساب');
    }
    try {
      await login(email, password);
    } catch (_) {}
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(AppConstants.prefAuthToken);
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(AppConstants.prefUserData);
    return str != null ? jsonDecode(str) : null;
  }

  // =========================================================================
  // 🏠 العقارات (Properties)
  // =========================================================================
  static Future<bool> addProperty({
    required String title,
    required String price,
    required String description,
    required String address,
    required double latitude,
    required double longitude,
    required String category,
    required String propertyType,
    required String bedrooms,
    required String bathrooms,
    required String area,
    required List<String> features,
    required List<File> images,
    File? video,
    String? livingRooms,
    String? streetWidth,
    String? age,
    bool? isFurnished,
    bool? hasKitchen,
    bool? hasAnnex,
    bool? hasCarEntrance,
    bool? hasElevator,
    bool? hasPool,
  }) async {
    try {
      List<String> imageUrls = [];
      String? videoUrl;

      try {
        debugPrint('☁️ [API] Uploading images...');
        imageUrls = await CloudinaryConfig.uploadImages(images);
        if (imageUrls.isEmpty && images.isNotEmpty) return false;

        if (video != null) {
          debugPrint('🎥 [API] Uploading video...');
          videoUrl = await CloudinaryConfig.uploadVideo(video);
        }
      } catch (e) {
        debugPrint('❌ [API] Cloudinary Error: $e');
        return false;
      }

      final response = await _sendRequest(
        'POST',
        '/properties',
        body: {
          'title': title,
          'price': price,
          'description': description,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'category': category,
          'propertyType': propertyType,
          'bedrooms': bedrooms,
          'bathrooms': bathrooms,
          'area': area,
          'features': features,
          'images': imageUrls,
          'videoUrl': videoUrl,
          'livingRooms': livingRooms,
          'streetWidth': streetWidth,
          'age': age,
          'isFurnished': isFurnished,
          'hasKitchen': hasKitchen,
          'hasAnnex': hasAnnex,
          'hasCarEntrance': hasCarEntrance,
          'hasElevator': hasElevator,
          'hasPool': hasPool,
        },
      );

      // ✅ مسح الكاش المحلي لضمان تحديث البيانات
      if (response.statusCode == 201 || response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        // سنقوم بحذف أي مفتاح كاش يبدأ بـ cache_properties
        final keys = prefs.getKeys();
        for (String key in keys) {
          if (key.startsWith(AppConstants.cachePropertiesBaseKey)) {
            await prefs.remove(key);
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('💥 [App] Error adding property: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchProperties({
    int limit = AppConstants.defaultPaginationLimit,
    int page = 1,
  }) async {
    // 1. التحقق من توفر الإنترنت أولاً
    bool online = await hasInternet();

    if (!online) {
      debugPrint('📴 [Offline] لا يوجد إنترنت، جلب العقارات من SQLite...');
      return await LocalDbService.getCachedProperties();
    }

    // 2. إذا كان هناك إنترنت، نقوم بمزامنة الطلبات المتأخرة أولاً
    await syncPendingRequests();

    // 3. جلب البيانات من السيرفر كالمعتاد
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${AppConstants.cachePropertiesBaseKey}_p${page}_l$limit';
    final cacheTimeKey = '${cacheKey}_time';

    final cachedData = prefs.getString(cacheKey);
    final cacheTimeStr = prefs.getString(cacheTimeKey);

    if (cachedData != null && cacheTimeStr != null) {
      final cacheTime = DateTime.parse(cacheTimeStr);
      if (DateTime.now().difference(cacheTime) < AppConstants.cacheDuration) {
        return List<Map<String, dynamic>>.from(jsonDecode(cachedData));
      }
    }

    debugPrint('⏳ [API] جلب قائمة العقارات (صفحة $page) من السيرفر...');
    try {
      final response = await _sendRequest(
        'GET',
        '/properties?limit=$limit&page=$page',
      );
      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(response.body));

        await prefs.setString(cacheKey, response.body);
        await prefs.setString(cacheTimeKey, DateTime.now().toIso8601String());

        // ✅ حفظ النسخة الأوفلاين (SQLite) للصفحة الأولى فقط لتبقى متاحة دائماً بدون إنترنت
        if (page == 1) {
          await LocalDbService.cachePropertiesList(list);
        }

        return list;
      }
    } catch (e) {
      // في حالة فشل السيرفر بشكل مفاجئ رغم وجود شبكة، نعرض الكاش المحلي
      debugPrint('⚠️ [Fallback] فشل السيرفر، جلب من SQLite كخيار بديل');
      return await LocalDbService.getCachedProperties();
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchPropertyDetails(String id) async {
    if (id.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${AppConstants.cachePropertyDetailBaseKey}$id';
    final cacheTimeKey = '${cacheKey}_time';

    final cachedData = prefs.getString(cacheKey);
    final cacheTimeStr = prefs.getString(cacheTimeKey);

    if (cachedData != null && cacheTimeStr != null) {
      final cacheTime = DateTime.parse(cacheTimeStr);
      if (DateTime.now().difference(cacheTime) < AppConstants.cacheDuration) {
        debugPrint('⚡ [Local Cache] جلب تفاصيل العقار ($id) من التخزين المحلي');
        return jsonDecode(cachedData);
      }
    }

    debugPrint('⏳ [API] جلب تفاصيل العقار ($id) من السيرفر...');
    final response = await _sendRequest('GET', '/properties/$id');
    if (response.statusCode == 200) {
      await prefs.setString(cacheKey, response.body);
      await prefs.setString(cacheTimeKey, DateTime.now().toIso8601String());
      return jsonDecode(response.body);
    }
    return null;
  }

  static Future<void> updateProperty(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _sendRequest('PUT', '/properties/$id', body: data);
    if (response.statusCode != 200) {
      throw Exception('فشل التحديث');
    } else {
      final prefs = await SharedPreferences.getInstance();
      // مسح كاش العقار المحدد
      await prefs.remove('${AppConstants.cachePropertyDetailBaseKey}$id');
      // مسح كل كاش القوائم
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith(AppConstants.cachePropertiesBaseKey)) {
          await prefs.remove(key);
        }
      }
    }
  }

  static Future<bool> deletePropertyAdmin(String propertyId) async {
    final response = await _sendRequest('DELETE', '/properties/$propertyId');
    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(
        '${AppConstants.cachePropertyDetailBaseKey}$propertyId',
      );
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith(AppConstants.cachePropertiesBaseKey)) {
          await prefs.remove(key);
        }
      }
      return true;
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> fetchMyProperties(
    String userId,
  ) async {
    final response = await _sendRequest('GET', '/properties?userId=$userId');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchArchivedProperties(
    String userId,
  ) async {
    final response = await _sendRequest(
      'GET',
      '/properties/archived?userId=$userId',
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }

  static Future<void> restoreProperty(String id) async {
    await _sendRequest('POST', '/properties/$id/restore');
  }

  static Future<void> deleteArchivedProperty(String id) async {
    await _sendRequest('DELETE', '/properties/$id');
  }

  static Future<bool> incrementPropertyViews(String propertyId) async {
    try {
      // ✅ إرسال userId في الـ body لتتبع المشاهدات
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(AppConstants.prefUserId);

      final response = await _sendRequest(
        'POST',
        '/properties/$propertyId/view',
        body: userId != null ? {'userId': userId} : null,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.remove(
          '${AppConstants.cachePropertyDetailBaseKey}$propertyId',
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // 👤 المستخدمين (Users)
  // =========================================================================
  static Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    if (userId.isEmpty) return null;
    debugPrint('🔍 [API] Fetching user profile for: $userId');
    final response = await _sendRequest('GET', '/users/$userId');
    if (response.statusCode == 200) {
      final data = Map<String, dynamic>.from(jsonDecode(response.body));
      debugPrint(
        '✅ [API] User profile fetched successfully: ${data['username']}',
      );
      debugPrint('📊 [API] Profile data: {');
      debugPrint('  - username: ${data['username']}');
      debugPrint('  - email: ${data['email']}');
      debugPrint('  - phone: ${data['phone'] ?? data['phoneNumber']}');
      debugPrint('  - bio: ${data['bio']?.isNotEmpty == true ? "✓" : "✗"}');
      debugPrint('  - isVerified: ${data['isVerified']}');
      debugPrint('  - isAdmin: ${data['isAdmin']}');
      debugPrint('  - isBanned: ${data['isBanned']}');
      debugPrint('  - role: ${data['role']}');
      debugPrint('  - reputationScore: ${data['reputationScore']}');
      debugPrint(
        '  - profileImageUrl: ${data['profileImageUrl']?.isNotEmpty == true ? "✓" : "✗"}',
      );
      debugPrint('  - createdAt: ${data['createdAt']?.toString()}');
      debugPrint('  - createdAt type: ${data['createdAt']?.runtimeType}');
      debugPrint('  - isOnline: ${data['isOnline']}');
      debugPrint('  - lastSeen: ${data['lastSeen']?.toString()}');
      debugPrint('}');

      final prefs = await SharedPreferences.getInstance();
      if (data['email'] == null) {
        data['email'] = prefs.getString(AppConstants.prefUserEmail);
      }
      await prefs.setString(AppConstants.prefUserData, jsonEncode(data));
      return data;
    }
    debugPrint('❌ [API] Failed to fetch user profile: ${response.statusCode}');
    return null;
  }

  static Future<List<Map<String, dynamic>>> fetchUserProperties(
    String userId,
  ) async {
    if (userId.isEmpty) return [];
    try {
      final response = await _sendRequest('GET', '/properties?userId=$userId');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('❌ Error fetching user properties: $e');
    }
    return [];
  }

  static Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final response = await _sendRequest('PUT', '/users/$userId', body: data);
    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      String? oldDataStr = prefs.getString(AppConstants.prefUserData);
      Map<String, dynamic> mergedData = oldDataStr != null
          ? Map.from(jsonDecode(oldDataStr))
          : {};
      mergedData.addAll(data);
      await prefs.setString(AppConstants.prefUserData, jsonEncode(mergedData));
    } else {
      throw Exception('فشل التحديث');
    }
  }

  static Future<void> updateFcmToken(String userId, String token) async {
    await _sendRequest('POST', '/users/$userId/fcm', body: {'fcmToken': token});
  }

  static Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await _sendRequest(
      'POST',
      '/users/$userId/online-status',
      body: {'isOnline': isOnline},
    );
  }

  static Future<void> toggleUserVerification(
    String userId,
    bool isVerified,
  ) async {
    await toggleUserVerificationAdmin(userId, isVerified);
  }

  // ✅ دالة لفحص حالة الإنترنت
  static Future<bool> hasInternet() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult is List) {
        return !connectivityResult.contains(ConnectivityResult.none);
      } else {
        return connectivityResult != ConnectivityResult.none;
      }
    } catch (e) {
      return true; // نفترض وجود إنترنت كوضع افتراضي في حال فشل الفحص
    }
  }

  // ✅ دالة المزامنة في الخلفية (ترسل ما تم حفظه بدون إنترنت)
  static Future<void> syncPendingRequests() async {
    final pending = await LocalDbService.getPendingRequests();
    if (pending.isEmpty) return;

    debugPrint(
      '🔄 [Sync] عاد الإنترنت! جاري مزامنة ${pending.length} طلبات معلقة...',
    );
    for (var req in pending) {
      try {
        await _sendRequest(
          req['method'],
          req['endpoint'],
          body: jsonDecode(req['body']),
        );
        // مسح الطلب بعد نجاح إرساله
        await LocalDbService.removePendingRequest(req['id']);
        debugPrint('✅ [Sync] تمت المزامنة بنجاح للطلب: ${req['endpoint']}');
      } catch (e) {
        debugPrint('❌ [Sync] فشل مزامنة الطلب، سيتم المحاولة لاحقاً.');
      }
    }
  }

  // =========================================================================
  // 💬 المحادثات (Chats)
  // =========================================================================
  static Future<List<Map<String, dynamic>>> fetchMyChats() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(AppConstants.prefUserId);
    if (userId == null) return [];
    final response = await _sendRequest('GET', '/chats?userId=$userId');
    if (response.statusCode == 200)
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchChatMessages(
    String chatId,
  ) async {
    final response = await _sendRequest('GET', '/chats/$chatId/messages');
    if (response.statusCode == 200)
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    return [];
  }

  static Future<Map<String, dynamic>?> fetchChatInfo(String chatId) async {
    final response = await _sendRequest('GET', '/chats/$chatId');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  static Future<void> sendMessage(
    String chatId,
    String text,
    String recipientId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final senderId = prefs.getString(AppConstants.prefUserId);
    await _sendRequest(
      'POST',
      '/chats/$chatId/messages',
      body: {'text': text, 'recipientId': recipientId, 'senderId': senderId},
    );
  }

  static Future<void> markChatAsRead(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(AppConstants.prefUserId);
    if (userId == null) return;
    try {
      await _sendRequest(
        'POST',
        '/chats/$chatId/mark-as-read',
        body: {'userId': userId},
      );
    } catch (e) {
      debugPrint('Error marking chat as read: $e');
    }
  }

  static Future<String> startChat(String propertyId, String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    final myId = prefs.getString(AppConstants.prefUserId);
    final response = await _sendRequest(
      'POST',
      '/chats',
      body: {
        'propertyId': propertyId,
        'participants': [myId, ownerId],
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201)
      return jsonDecode(response.body)['chatId'];
    throw Exception('فشل بدء المحادثة');
  }

  // =========================================================================
  // 🤝 الصفقات والمفضلات (Deals & Favorites)
  // =========================================================================
  static Future<void> submitDealRequest(
    String propertyId,
    String sellerId,
    String dealType,
  ) async {
    await _sendRequest(
      'POST',
      '/deals',
      body: {
        'propertyId': propertyId,
        'sellerId': sellerId,
        'dealType': dealType,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> fetchDeals(
    String userId,
    String role,
  ) async {
    final response = await _sendRequest(
      'GET',
      '/deals?userId=$userId&role=$role',
    );
    if (response.statusCode == 200)
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    return [];
  }

  static Future<Map<String, dynamic>> fetchUserRatingSummary(
    String userId,
  ) async {
    final profile = await fetchUserProfile(userId);
    return {
      'reputationScore': profile?['reputationScore'] ?? 0.0,
      'reputationCount': profile?['reputationCount'] ?? 0,
    };
  }

  static Future<List<Map<String, dynamic>>> fetchUserReviews(
    String userId,
  ) async {
    final response = await _sendRequest('GET', '/users/$userId/reviews');
    if (response.statusCode == 200)
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    return [];
  }

  static Future<void> submitRating(
    String targetUserId,
    double rating,
    String comment,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final myId = prefs.getString(AppConstants.prefUserId);
    await _sendRequest(
      'POST',
      '/users/$targetUserId/reviews',
      body: {'rating': rating, 'comment': comment, 'reviewerId': myId},
    );
  }

  static Future<List<Map<String, dynamic>>> fetchFavorites(
    String userId,
  ) async {
    try {
      debugPrint('🔍 [API] Fetching favorites for user: $userId');
      final response = await _sendRequest('GET', '/users/$userId/favorites');
      if (response.statusCode == 200) {
        final favorites = List<Map<String, dynamic>>.from(
          jsonDecode(response.body),
        );
        debugPrint('✅ [API] Fetched ${favorites.length} favorite properties');
        return favorites;
      }
      debugPrint(
        '⚠️ [API] Failed to fetch favorites: ${response.statusCode} - ${response.body}',
      );
      return [];
    } catch (e, stackTrace) {
      debugPrint('❌ [API] Error fetching favorites: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  // ✅ جلب العقارات المشاهدة
  static Future<List<Map<String, dynamic>>> fetchViewedProperties(
    String userId,
  ) async {
    try {
      debugPrint('🔍 [API] Fetching viewed properties for user: $userId');
      final response = await _sendRequest(
        'GET',
        '/users/$userId/viewed-properties',
      );
      if (response.statusCode == 200) {
        final viewed = List<Map<String, dynamic>>.from(
          jsonDecode(response.body),
        );
        debugPrint('✅ [API] Fetched ${viewed.length} viewed properties');
        return viewed;
      }
      debugPrint(
        '⚠️ [API] Failed to fetch viewed properties: ${response.statusCode} - ${response.body}',
      );
      return [];
    } catch (e, stackTrace) {
      debugPrint('❌ [API] Error fetching viewed properties: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  static Future<void> toggleFavorite(String propertyId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(AppConstants.prefUserId);
    if (userId == null) return;

    // تحديد ما إذا كان مفضلاً أم لا (لنفترض أننا نضيفه الآن)
    bool isOnline = await hasInternet();

    if (!isOnline) {
      // ✅ حفظ الطلب في طابور المزامنة (Offline Mode)
      await LocalDbService.addPendingRequest(
        'POST',
        '/users/$userId/favorites',
        {'propertyId': propertyId},
      );
      return;
    }

    // إذا كان هناك إنترنت، يتم إرساله فوراً
    try {
      await _sendRequest(
        'POST',
        '/users/$userId/favorites',
        body: {'propertyId': propertyId},
      );
    } catch (_) {}
  }

  // =========================================================================
  // 🛠️ الأدمن (Admin)
  // =========================================================================
  static Future<Map<String, dynamic>> fetchAdminStats() async {
    final response = await _sendRequest('GET', '/admin/stats');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {'users': 0, 'properties': 0};
  }

  static Future<List<Map<String, dynamic>>> fetchAllUsers({
    int limit = 20,
    dynamic lastCreatedAt,
    String? searchQuery,
  }) async {
    String query = '/admin/users?limit=$limit';
    if (searchQuery != null && searchQuery.isNotEmpty)
      query += '&search=$searchQuery';
    final response = await _sendRequest('GET', query);
    if (response.statusCode == 200)
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    return [];
  }

  static Future<void> toggleUserBan(String userId, bool ban) async {
    await _sendRequest(
      'POST',
      '/admin/users/$userId/ban',
      body: {'isBanned': ban},
    );
  }

  static Future<void> toggleUserVerificationAdmin(
    String userId,
    bool isVerified,
  ) async {
    await _sendRequest(
      'POST',
      '/admin/users/$userId/verify',
      body: {'isVerified': isVerified},
    );
  }

  static Future<void> toggleUserAdmin(String userId, bool makeAdmin) async {
    await _sendRequest(
      'POST',
      '/admin/users/$userId/admin',
      body: {'isAdmin': makeAdmin},
    );
  }

  static Future<List<Map<String, dynamic>>> fetchAllChats() async {
    final response = await _sendRequest('GET', '/admin/chats');
    if (response.statusCode == 200)
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    return [];
  }

  static Future<Map<String, dynamic>?> fetchAdminChatMessages(
    String chatId,
  ) async {
    final response = await _sendRequest('GET', '/admin/chats/$chatId/messages');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  static Future<bool> deleteChat(String chatId) async {
    final response = await _sendRequest('DELETE', '/admin/chats/$chatId');
    return response.statusCode == 200;
  }

  static Future<List<Map<String, dynamic>>> fetchReports() async {
    final response = await _sendRequest('GET', '/admin/reports');
    if (response.statusCode == 200)
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    return [];
  }

  static Future<void> submitReport(Map<String, dynamic> reportData) async {
    try {
      await _sendRequest('POST', '/reports', body: reportData);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> fetchReport(String reportId) async {
    try {
      final response = await _sendRequest('GET', '/reports/$reportId');
      if (response.statusCode == 200)
        return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateReportStatus(String reportId, String status) async {
    try {
      final response = await _sendRequest(
        'PUT',
        '/admin/reports/$reportId',
        body: {'status': status},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteReport(String reportId) async {
    final response = await _sendRequest('DELETE', '/admin/reports/$reportId');
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> fetchAppSettings() async {
    final response = await _sendRequest('GET', '/admin/settings/public');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  static Future<List<Map<String, dynamic>>> fetchAnnouncementViews(
    String announcementId, {
    int limit = 50,
  }) async {
    final response = await _sendRequest(
      'GET',
      '/admin/announcement-views?announcementId=$announcementId&limit=$limit',
    );
    if (response.statusCode == 200)
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    return [];
  }

  static Future<void> updateAppSettings(Map<String, dynamic> settings) async {
    final response = await _sendRequest(
      'POST',
      '/admin/settings',
      body: settings,
    );
    if (response.statusCode != 200) throw Exception('فشل تحديث الإعدادات');
  }

  static Future<bool> recordAnnouncementView(String announcementId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(AppConstants.prefUserId);
      if (userId == null) return false;

      final response = await _sendRequest(
        'POST',
        '/users/$userId/announcement-view',
        body: {'announcementId': announcementId},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // ⚙️ وظائف مساعدة داخلية (Helpers)
  // =========================================================================
  static Future<String?> _ensureValidToken(SharedPreferences prefs) async {
    String? token = prefs.getString(AppConstants.prefAuthToken);
    final expiryStr = prefs.getString(AppConstants.prefTokenExpiry);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && expiry.isBefore(DateTime.now().add(_refreshSkew))) {
        token = await _refreshTokenThrottled();
      }
    }
    return token;
  }

  static Future<String?> _refreshTokenThrottled() async {
    if (_refreshFuture != null) return _refreshFuture;
    final future = _refreshToken();
    _refreshFuture = future;
    try {
      return await future;
    } finally {
      _refreshFuture = null;
    }
  }

  static Future<String?> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(AppConstants.prefRefreshToken);
      if (refreshToken == null) return null;

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(AppConstants.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['token'];
        if (newToken != null) {
          await _saveAuthData(
            prefs,
            token: newToken,
            refreshToken: data['refreshToken'] ?? refreshToken,
            expiresInSeconds: _parseExpiry(data['expiresIn']),
          );
          WebSocketService.reconnectWithNewToken();
          return newToken;
        }
      }
    } catch (e) {
      debugPrint('❌ [API] Refresh Error: $e');
    }
    return null;
  }

  static Future<void> _saveAuthData(
    SharedPreferences prefs, {
    required String token,
    required String refreshToken,
    required int? expiresInSeconds,
  }) async {
    await prefs.setString(AppConstants.prefAuthToken, token);
    await prefs.setString(AppConstants.prefRefreshToken, refreshToken);
    if (expiresInSeconds != null) {
      await prefs.setString(
        AppConstants.prefTokenExpiry,
        DateTime.now()
            .add(Duration(seconds: expiresInSeconds))
            .toIso8601String(),
      );
    }
  }

  static int? _parseExpiry(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
