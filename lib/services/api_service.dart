import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ✅ العنوان الصحيح للسيرفر
  static const String baseUrl = 'http://72.60.80.201:3001/api';
  static const String currentAppVersion = '1.0.0';

  // 🔔 دالة استدعاء (Callback) يتم تنفيذها عند انتهاء صلاحية الجلسة
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
  // 🔄 أدوات مساعدة (Helpers)
  // =========================================================================

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ✅ دالة مركزية لمعالجة الاستجابة واكتشاف انتهاء الجلسة (401)
  static http.Response _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      debugPrint('⛔ [API] Token Expired or Unauthorized (401)');
      if (onTokenExpired != null) {
        onTokenExpired!(); // استدعاء دالة الخروج في main.dart
      }
      // يمكن رمي استثناء لإيقاف العملية الحالية
      // throw Exception('انتهت صلاحية الجلسة');
    }
    return response;
  }

  // =========================================================================
  // 🔐 المصادقة والمستخدمين (Auth & Users)
  // =========================================================================

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('auth_token');
  }

  static Future<void> login(String email, String password) async {
    debugPrint('🌐 [API] Login request: $baseUrl/auth/login');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [API] Login response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        if (data['userData'] != null && data['userData']['isBanned'] == true) {
          throw Exception('تم حظر هذا الحساب من قبل الإدارة');
        }

        final token = data['token'] ?? data['idToken'] ?? '';
        await prefs.setString('auth_token', token);
        await prefs.setString('user_id', data['userId'] ?? data['uid'] ?? '');
        await prefs.setString('user_email', email);

        if (data['userData'] != null) {
          await prefs.setString('user_data', jsonEncode(data['userData']));
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error'] ?? errorData['message'] ?? 'فشل تسجيل الدخول',
        );
      }
    } catch (e) {
      debugPrint('💥 [API] Login Error: $e');
      rethrow;
    }
  }

  static Future<void> signup(
    String email,
    String password,
    String username,
    String phone, {
    String role = 'user',
  }) async {
    try {
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
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 201 && response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'فشل إنشاء الحساب');
      }
      try {
        await login(email, password);
      } catch (_) {}
    } catch (e) {
      debugPrint('💥 [API] Signup Error: $e');
      rethrow;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    debugPrint('👋 [API] User logged out and cache cleared.');
  }

  static Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: headers,
      );

      // هنا لا نستدعي _handleResponse لتجنب التكرار أثناء بدء التطبيق، لكن يمكن إضافتها
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));
        if (data['email'] == null) {
          final prefs = await SharedPreferences.getInstance();
          final localEmail = prefs.getString('user_email');
          if (localEmail != null) data['email'] = localEmail;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(data));
        return data;
      } else if (response.statusCode == 401) {
        if (onTokenExpired != null) onTokenExpired!();
      }
    } catch (e) {
      debugPrint('💥 [API] Fetch Profile Error: $e');
    }
    return null;
  }

  // دالة توثيق الحساب (نسخة المستخدم) - قد لا تستخدم ولكن نحتفظ بها
  static Future<void> toggleUserVerification(
    String userId,
    bool isVerified,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/verify'),
        headers: headers,
        body: jsonEncode({'isVerified': isVerified}),
      );
      _handleResponse(response);
      if (response.statusCode != 200) throw Exception('Failed verification');
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/users/$userId'),
            headers: headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      _handleResponse(response);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        String? oldDataStr = prefs.getString('user_data');
        Map<String, dynamic> mergedData = {};
        if (oldDataStr != null) {
          mergedData = Map<String, dynamic>.from(jsonDecode(oldDataStr));
        }
        mergedData.addAll(data);
        await prefs.setString('user_data', jsonEncode(mergedData));
      } else {
        throw Exception('فشل التحديث: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('user_data');
    return str != null ? jsonDecode(str) : null;
  }

  static Future<void> updateFcmToken(String userId, String token) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/users/$userId/fcm'),
        headers: {'Content-Type': 'application/json', ...(await _getHeaders())},
        body: jsonEncode({'fcmToken': token}),
      );
    } catch (e) {
      debugPrint('⚠️ [API] Failed to update FCM token: $e');
    }
  }

  static Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/users/$userId/online-status'),
        headers: {'Content-Type': 'application/json', ...(await _getHeaders())},
        body: jsonEncode({'isOnline': isOnline}),
      );
    } catch (e) {
      debugPrint('⚠️ [API] Failed to update online status: $e');
    }
  }

  // =========================================================================
  // 🏠 العقارات (Properties)
  // =========================================================================

  static Future<List<Map<String, dynamic>>> fetchProperties() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/properties'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('💥 [API] Fetch Properties Error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchPropertyDetails(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/properties/$id'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching property details: $e');
    }
    return null;
  }

  static Future<void> addProperty(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/properties'),
      headers: headers,
      body: jsonEncode(data),
    );
    _handleResponse(response);
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to add property: ${response.body}');
    }
  }

  static Future<void> updateProperty(
    String id,
    Map<String, dynamic> data,
  ) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/properties/$id'),
      headers: headers,
      body: jsonEncode(data),
    );
    _handleResponse(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to update property');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMyProperties(
    String userId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/properties?userId=$userId'),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching my properties: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchArchivedProperties(
    String userId,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/properties/archived?userId=$userId'),
        headers: headers,
      );
      _handleResponse(response);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching archive: $e');
    }
    return [];
  }

  static Future<void> restoreProperty(String id) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/properties/$id/restore'),
      headers: headers,
    );
    _handleResponse(response);
  }

  static Future<void> deleteArchivedProperty(String id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/properties/$id'),
      headers: headers,
    );
    _handleResponse(response);
  }

  // =========================================================================
  // 💬 المحادثات (Chats)
  // =========================================================================

  static Future<List<Map<String, dynamic>>> fetchMyChats() async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/chats?userId=$userId'),
        headers: headers,
      );
      _handleResponse(response);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching chats: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchChatMessages(
    String chatId,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/chats/$chatId/messages'),
        headers: headers,
      );
      _handleResponse(response);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchChatInfo(String chatId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/chats/$chatId'), headers: headers)
          .timeout(const Duration(seconds: 15));
      _handleResponse(response);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (_) {}
    return null;
  }

  static Future<void> sendMessage(
    String chatId,
    String text,
    String recipientId,
  ) async {
    final headers = await _getHeaders();
    final prefs = await SharedPreferences.getInstance();
    final senderId = prefs.getString('user_id');
    final response = await http.post(
      Uri.parse('$baseUrl/chats/$chatId/messages'),
      headers: headers,
      body: jsonEncode({
        'text': text,
        'recipientId': recipientId,
        'senderId': senderId,
      }),
    );
    _handleResponse(response);
  }

  static Future<String> startChat(String propertyId, String ownerId) async {
    final headers = await _getHeaders();
    final prefs = await SharedPreferences.getInstance();
    final myId = prefs.getString('user_id');

    final response = await http.post(
      Uri.parse('$baseUrl/chats'),
      headers: headers,
      body: jsonEncode({
        'propertyId': propertyId,
        'participants': [myId, ownerId],
      }),
    );
    _handleResponse(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body)['chatId'];
    }
    throw Exception('Failed to start chat');
  }

  // =========================================================================
  // 🤝 الصفقات والمفضلات والتقييمات
  // =========================================================================

  static Future<void> submitDealRequest(
    String propertyId,
    String sellerId,
    String dealType,
  ) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/deals'),
      headers: headers,
      body: jsonEncode({
        'propertyId': propertyId,
        'sellerId': sellerId,
        'dealType': dealType,
      }),
    );
    _handleResponse(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to submit deal request');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDeals(
    String userId,
    String role,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/deals?userId=$userId&role=$role'),
        headers: headers,
      );
      _handleResponse(response);
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } catch (_) {}
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
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/reviews'),
      );
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } catch (_) {}
    return [];
  }

  static Future<void> submitRating(
    String targetUserId,
    double rating,
    String comment,
  ) async {
    final headers = await _getHeaders();
    final prefs = await SharedPreferences.getInstance();
    final myId = prefs.getString('user_id');
    final response = await http.post(
      Uri.parse('$baseUrl/users/$targetUserId/reviews'),
      headers: headers,
      body: jsonEncode({
        'rating': rating,
        'comment': comment,
        'reviewerId': myId,
      }),
    );
    _handleResponse(response);
  }

  static Future<List<Map<String, dynamic>>> fetchFavorites(
    String userId,
  ) async {
    try {
      final headers = await _getHeaders();
      if (userId.isEmpty) return [];
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/favorites'),
        headers: headers,
      );
      _handleResponse(response);
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } catch (_) {}
    return [];
  }

  static Future<void> toggleFavorite(String propertyId) async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) throw Exception('User not logged in');

      bool isFavorited = false;
      try {
        final favs = await fetchFavorites(userId);
        isFavorited = favs.any(
          (f) => (f['id'] ?? f['_id']).toString() == propertyId,
        );
      } catch (_) {}

      http.Response response;
      if (!isFavorited) {
        response = await http.post(
          Uri.parse('$baseUrl/users/$userId/favorites'),
          headers: headers,
          body: jsonEncode({'propertyId': propertyId}),
        );
      } else {
        response = await http.delete(
          Uri.parse('$baseUrl/users/$userId/favorites/$propertyId'),
          headers: headers,
        );
      }
      _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // =========================================================================
  // 🛠️ الأدمن (Admin)
  // =========================================================================

  static Future<Map<String, dynamic>> fetchAdminStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/stats'),
        headers: headers,
      );
      _handleResponse(response);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (_) {}
    return {'users': 0, 'properties': 0};
  }

  // ✅ هذه الدالة المحدثة التي تدعم Pagination والتي يجب أن تحل محل النسخة القديمة
  static Future<List<Map<String, dynamic>>> fetchAllUsers({
    int limit = 20,
    String? lastCreatedAt,
    String? searchQuery,
  }) async {
    try {
      final headers = await _getHeaders();
      String queryString = 'limit=$limit';
      if (lastCreatedAt != null && lastCreatedAt.isNotEmpty) {
        queryString += '&lastCreatedAt=$lastCreatedAt';
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryString += '&search=$searchQuery';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/admin/users?$queryString'),
        headers: headers,
      );
      _handleResponse(response);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
    return [];
  }

  static Future<void> toggleUserBan(String userId, bool ban) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/users/$userId/ban'),
      headers: headers,
      body: jsonEncode({'isBanned': ban}),
    );
    _handleResponse(response);
  }

  // هذه نسخة الأدمن من التوثيق
  static Future<void> toggleUserVerificationAdmin(
    String userId,
    bool isVerified,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/verify'),
        headers: headers,
        body: jsonEncode({'isVerified': isVerified}),
      );
      _handleResponse(response);
      if (response.statusCode != 200) throw Exception('Failed verification');
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> toggleUserAdmin(String userId, bool makeAdmin) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/users/$userId/admin'),
      headers: headers,
      body: jsonEncode({'isAdmin': makeAdmin}),
    );
    _handleResponse(response);
  }

  static Future<List<Map<String, dynamic>>> fetchAllChats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/chats'),
        headers: headers,
      );
      _handleResponse(response);
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>?> fetchAdminChatMessages(
    String chatId,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/chats/$chatId/messages'),
        headers: headers,
      );
      _handleResponse(response);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (_) {}
    return null;
  }

  static Future<bool> updateReportStatus(String reportId, String status) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/admin/reports/$reportId'),
        headers: headers,
        body: jsonEncode({'status': status}),
      );
      _handleResponse(response);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteReport(String reportId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/reports/$reportId'),
        headers: headers,
      );
      _handleResponse(response);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deletePropertyAdmin(String propertyId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/properties/$propertyId'),
        headers: headers,
      );
      _handleResponse(response);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteChat(String chatId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/chats/$chatId'),
        headers: headers,
      );
      _handleResponse(response);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchReports() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/reports'),
        headers: headers,
      );
      _handleResponse(response);
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } catch (_) {}
    return [];
  }

  static Future<void> submitReport(Map<String, dynamic> reportData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/reports'),
      headers: headers,
      body: jsonEncode(reportData),
    );
    _handleResponse(response);
  }

  static Future<Map<String, dynamic>> fetchAppSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/settings/public'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (_) {}
    return {};
  }

  static Future<void> updateAppSettings(Map<String, dynamic> settings) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/settings'),
        headers: headers,
        body: jsonEncode(settings),
      );
      _handleResponse(response);
      if (response.statusCode != 200)
        throw Exception('Failed to update app settings');
    } catch (e) {
      rethrow;
    }
  }
}
