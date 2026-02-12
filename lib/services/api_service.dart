import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart'; // تأكد من إضافة المكتبة
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'websocket_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:aqar_app/config/cloudinary_config.dart'; // تأكد من المسار

class ApiService {
  // ✅ العنوان الأساسي للسيرفر
  static const String baseUrl = 'http://72.60.80.201:3001/api';
  static const String currentAppVersion = '1.0.0';

  // ⏱️ إعدادات الوقت
  static const Duration defaultTimeout = Duration(seconds: 15);
  static const Duration longTimeout = Duration(seconds: 30);

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
    return compareVersions(currentAppVersion, minRequiredVersion) < 0;
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

    final uri = Uri.parse(
      endpoint.startsWith('http') ? endpoint : '$baseUrl$endpoint',
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
    switch (method) {
      case 'POST':
        return http
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(defaultTimeout);
      case 'PUT':
        return http
            .put(uri, headers: headers, body: jsonEncode(body))
            .timeout(defaultTimeout);
      case 'DELETE':
        return http.delete(uri, headers: headers).timeout(defaultTimeout);
      case 'GET':
      default:
        return http.get(uri, headers: headers).timeout(defaultTimeout);
    }
  }

  // =========================================================================
  // 🔐 المصادقة
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
            Uri.parse('$baseUrl/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          )
          .timeout(defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await _saveAuthData(
          prefs,
          token: data['token'],
          refreshToken: data['refreshToken'],
          expiresInSeconds: _parseExpiry(data['expiresIn']),
        );
        if (data['userId'] != null)
          await prefs.setString('user_id', data['userId']);
        if (data['email'] != null)
          await prefs.setString('user_email', data['email']);
        if (data['userData'] != null)
          await prefs.setString('user_data', jsonEncode(data['userData']));
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
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(defaultTimeout);

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
      await prefs.setString('user_id', data['userId']);
      await prefs.setString('user_email', email);
      if (data['userData'] != null)
        await prefs.setString('user_data', jsonEncode(data['userData']));
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
          Uri.parse('$baseUrl/auth/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'username': username,
            'phone': phone,
            'role': role,
          }),
        )
        .timeout(defaultTimeout);

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
    return prefs.containsKey('auth_token');
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('user_data');
    return str != null ? jsonDecode(str) : null;
  }

  // =========================================================================
  // 🏠 العقارات (Properties) - ✅ تم التعديل لتوافق الكنترولر
  // =========================================================================
  static Future<bool> addProperty({
    required String title,
    required String price,
    required String description,
    required String address,
    required double latitude,
    required double longitude,
    required String category,
    required String bedrooms,
    required String bathrooms,
    required String area,
    required List<String> features,
    required List<File> images, // يقبل ملفات
    File? video, // يقبل ملف
    // الحقول الإضافية
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

      // 1. رفع الوسائط إلى Cloudinary
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

      // 2. إرسال البيانات للسيرفر
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

      return (response.statusCode == 201 || response.statusCode == 200);
    } catch (e) {
      debugPrint('💥 [App] Error adding property: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchProperties({
    int limit = 50,
  }) async {
    final response = await _sendRequest('GET', '/properties?limit=$limit');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchPropertyDetails(String id) async {
    if (id.isEmpty) return null;
    final response = await _sendRequest('GET', '/properties/$id');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  static Future<void> updateProperty(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _sendRequest('PUT', '/properties/$id', body: data);
    if (response.statusCode != 200) throw Exception('فشل التحديث');
  }

  static Future<bool> deletePropertyAdmin(String propertyId) async {
    final response = await _sendRequest('DELETE', '/properties/$propertyId');
    return response.statusCode == 200;
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

  // =========================================================================
  // 👤 المستخدمين
  // =========================================================================
  static Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    if (userId.isEmpty) return null;
    final response = await _sendRequest('GET', '/users/$userId');
    if (response.statusCode == 200) {
      final data = Map<String, dynamic>.from(jsonDecode(response.body));
      final prefs = await SharedPreferences.getInstance();
      if (data['email'] == null) {
        data['email'] = prefs.getString('user_email');
      }
      await prefs.setString('user_data', jsonEncode(data));
      return data;
    }
    return null;
  }

  static Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final response = await _sendRequest('PUT', '/users/$userId', body: data);
    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      String? oldDataStr = prefs.getString('user_data');
      Map<String, dynamic> mergedData = oldDataStr != null
          ? Map.from(jsonDecode(oldDataStr))
          : {};
      mergedData.addAll(data);
      await prefs.setString('user_data', jsonEncode(mergedData));
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

  // =========================================================================
  // 💬 المحادثات
  // =========================================================================
  static Future<List<Map<String, dynamic>>> fetchMyChats() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
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
    final senderId = prefs.getString('user_id');
    await _sendRequest(
      'POST',
      '/chats/$chatId/messages',
      body: {'text': text, 'recipientId': recipientId, 'senderId': senderId},
    );
  }

  static Future<String> startChat(String propertyId, String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    final myId = prefs.getString('user_id');
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
  // 🤝 الصفقات والمفضلات
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
    final myId = prefs.getString('user_id');
    await _sendRequest(
      'POST',
      '/users/$targetUserId/reviews',
      body: {'rating': rating, 'comment': comment, 'reviewerId': myId},
    );
  }

  static Future<List<Map<String, dynamic>>> fetchFavorites(
    String userId,
  ) async {
    final response = await _sendRequest('GET', '/users/$userId/favorites');
    if (response.statusCode == 200)
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    return [];
  }

  static Future<void> toggleFavorite(String propertyId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    bool isFavorited = false;
    try {
      final favs = await fetchFavorites(userId);
      isFavorited = favs.any(
        (f) => (f['id'] ?? f['_id']).toString() == propertyId,
      );
    } catch (_) {}

    if (!isFavorited) {
      await _sendRequest(
        'POST',
        '/users/$userId/favorites',
        body: {'propertyId': propertyId},
      );
    } else {
      await _sendRequest('DELETE', '/users/$userId/favorites/$propertyId');
    }
  }

  // =========================================================================
  // 🛠️ الأدمن
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
    await _sendRequest('POST', '/reports', body: reportData);
  }

  static Future<bool> updateReportStatus(String reportId, String status) async {
    final response = await _sendRequest(
      'PUT',
      '/admin/reports/$reportId',
      body: {'status': status},
    );
    return response.statusCode == 200;
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

  static Future<void> updateAppSettings(Map<String, dynamic> settings) async {
    final response = await _sendRequest(
      'POST',
      '/admin/settings',
      body: settings,
    );
    if (response.statusCode != 200) throw Exception('فشل تحديث الإعدادات');
  }

  // =========================================================================
  // ⚙️ وظائف مساعدة داخلية
  // =========================================================================
  static Future<String?> _ensureValidToken(SharedPreferences prefs) async {
    String? token = prefs.getString('auth_token');
    final expiryStr = prefs.getString('auth_token_expiry');
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
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) return null;

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(defaultTimeout);

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
    await prefs.setString('auth_token', token);
    await prefs.setString('refresh_token', refreshToken);
    if (expiresInSeconds != null) {
      await prefs.setString(
        'auth_token_expiry',
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
