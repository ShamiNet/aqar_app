import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  // عنوان السيرفر (البروكسي)
  static const String baseUrl = 'http://72.60.80.201:3001/api';
  // الإصدار الحالي للتطبيق
  static const String currentAppVersion = '1.0.0';

  // =========================================================================
  // 🔄 دالة مقارنة الإصدارات (Version Comparison)
  // =========================================================================

  /// مقارنة نسختين
  /// return: -1 إذا كانت v1 < v2، 0 إذا كانت متساوية، 1 إذا كانت v1 > v2
  static int compareVersions(String v1, String v2) {
    print('📊 [Version] Comparing: $v1 vs $v2');

    try {
      final version1 = v1.split('.').map(int.parse).toList();
      final version2 = v2.split('.').map(int.parse).toList();

      // تأكد من أن كلا الإصدارات لهما نفس العدد من الأجزاء
      while (version1.length < version2.length) version1.add(0);
      while (version2.length < version1.length) version2.add(0);

      for (int i = 0; i < version1.length; i++) {
        if (version1[i] < version2[i]) {
          print('✅ [Version] $v1 < $v2 (Needs Update)');
          return -1;
        } else if (version1[i] > version2[i]) {
          print('✅ [Version] $v1 > $v2 (Up to Date)');
          return 1;
        }
      }

      print('✅ [Version] $v1 = $v2 (Same Version)');
      return 0;
    } catch (e) {
      print('❌ [Version] Error comparing versions: $e');
      return 0;
    }
  }

  /// التحقق مما إذا كان التحديث مطلوباً
  static bool isUpdateRequired(String minRequiredVersion) {
    return compareVersions(currentAppVersion, minRequiredVersion) < 0;
  }

  // دالة مساعدة لجلب الهيدرز (تتضمن التوكن تلقائياً)
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token != null) {
      debugPrint('🔑 [API] Using auth token');
    } else {
      debugPrint('⚠️ [API] No auth token found');
    }

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ---------------------------------------------------------------------------
  // 🔐 المصادقة (Auth)
  // ---------------------------------------------------------------------------

  static Future<void> login(String email, String password) async {
    debugPrint('🌐 [API] Sending login request to: $baseUrl/auth/login');
    debugPrint('📧 [API] Email: $email');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      debugPrint('📥 [API] Response status: ${response.statusCode}');
      debugPrint('📥 [API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        // ✅ فحص ما إذا كان المستخدم محظوراً
        final userData = data['userData'];
        if (userData != null && userData['isBanned'] == true) {
          debugPrint('🚫 [API] User is banned! Login rejected.');
          throw Exception('تم حظر هذا الحساب من قبل الإدارة');
        }

        // حفظ الـ token من السيرفر
        final token = data['token'] ?? data['idToken'] ?? '';
        await prefs.setString('auth_token', token);
        await prefs.setString('user_id', data['userId'] ?? data['uid'] ?? '');
        await prefs.setString('user_email', email);

        // حفظ بيانات المستخدم إذا كانت متوفرة
        if (data['userData'] != null) {
          await prefs.setString('user_data', jsonEncode(data['userData']));
        }

        debugPrint('✅ [API] Login successful! Token saved.');
      } else {
        final error =
            jsonDecode(response.body)['error'] ??
            jsonDecode(response.body)['message'] ??
            'فشل تسجيل الدخول';
        debugPrint('❌ [API] Login failed: $error');
        throw Exception(error);
      }
    } catch (e) {
      debugPrint('💥 [API] Exception during login: $e');
      rethrow;
    }
  }

  static Future<void> signup(
    String email,
    String password,
    String username,
    String phone,
  ) async {
    debugPrint('🌐 [API] Sending signup request to: $baseUrl/auth/signup');
    debugPrint('📧 [API] Email: $email, Username: $username');

    try {
      // 1. إنشاء الحساب على السيرفر
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'username': username,
          'phone': phone,
        }),
      );

      debugPrint('📥 [API] Response status: ${response.statusCode}');
      debugPrint('📥 [API] Response body: ${response.body}');

      if (response.statusCode != 201 && response.statusCode != 200) {
        final error =
            jsonDecode(response.body)['error'] ??
            jsonDecode(response.body)['message'] ??
            'فشل إنشاء الحساب';
        debugPrint('❌ [API] Signup failed: $error');
        throw Exception(error);
      }

      // 2. تسجيل الدخول تلقائياً للحصول على token
      debugPrint('🔐 [API] Auto-login after signup...');
      try {
        await login(email, password);
        debugPrint('✅ [API] Auto-login successful!');
      } catch (loginError) {
        debugPrint('⚠️ [API] Auto-login failed: $loginError');

        // كخطة بديلة، احفظ البيانات من response الـ signup
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        final userId = data['userId'] ?? data['uid'] ?? '';
        await prefs.setString('user_id', userId);
        await prefs.setString('user_email', email);

        final userData = {
          'email': email,
          'username': username,
          'phone': phone,
          'userId': userId,
        };
        await prefs.setString('user_data', jsonEncode(userData));

        // حفظ token بسيط كبديل
        if (data['token'] != null) {
          await prefs.setString('auth_token', data['token']);
        }
      }

      debugPrint('✅ [API] Signup successful!');
    } catch (e) {
      debugPrint('💥 [API] Exception during signup: $e');
      rethrow;
    }
  }

  static Future<void> logout() async {
    debugPrint('🚪 [API] Logging out...');

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    debugPrint('✅ [API] Logged out successfully');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final hasToken =
        prefs.containsKey('auth_token') &&
        prefs.getString('auth_token')!.isNotEmpty;
    debugPrint('🔍 [API] User logged in: $hasToken');
    return hasToken;
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 🏠 العقارات (Properties)
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> fetchProperties() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/properties'));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching properties: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchPropertyDetails(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/properties/$id'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching property details: $e');
    }
    return null;
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

  static Future<void> addProperty(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/properties'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
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
    if (response.statusCode != 200) {
      throw Exception('Failed to update property');
    }
  }

  // ---------------------------------------------------------------------------
  // 📂 الأرشيف (Archive)
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> fetchArchivedProperties(
    String userId,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/properties/archived?userId=$userId'),
        headers: headers,
      );
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
    await http.post(
      Uri.parse('$baseUrl/properties/$id/restore'),
      headers: headers,
    );
  }

  static Future<void> deleteArchivedProperty(String id) async {
    final headers = await _getHeaders();
    await http.delete(Uri.parse('$baseUrl/properties/$id'), headers: headers);
  }

  // ---------------------------------------------------------------------------
  // 👤 المستخدمين (Users)
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      debugPrint('🔍 [API] Fetching user profile for: $userId');
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: headers,
      );

      debugPrint('📥 [API] Profile response status: ${response.statusCode}');
      debugPrint('📥 [API] Profile response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ [API] Profile fetched successfully');
        debugPrint('🔍 [API] isBanned value in response: ${data['isBanned']}');
        return data;
      } else {
        debugPrint('❌ [API] Failed to fetch profile: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('💥 [API] Error fetching user profile: $e');
    }
    return null;
  }

  static Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update profile');
    }

    // تحديث البيانات المحلية أيضاً
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(data));
  }

  static Future<void> updateFcmToken(String userId, String token) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/users/$userId/fcm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcmToken': token}),
      );
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  // تحديث حالة الاتصال (متصل/غير متصل)
  static Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/users/$userId/online-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isOnline': isOnline}),
      );
      debugPrint('✅ [API] Online status updated: $isOnline');
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 💬 المحادثات (Chat)
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> fetchMyChats() async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      final response = await http.get(
        Uri.parse('$baseUrl/chats?userId=$userId'),
        headers: headers,
      );
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
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
    return [];
  }

  static Future<void> sendMessage(
    String chatId,
    String text,
    String recipientId,
  ) async {
    final headers = await _getHeaders();

    // ✅ جلب معرف المرسل (أنا) من الذاكرة
    final prefs = await SharedPreferences.getInstance();
    final senderId = prefs.getString('user_id');

    if (senderId == null) throw Exception('User ID not found');

    await http.post(
      Uri.parse('$baseUrl/chats/$chatId/messages'),
      headers: headers,
      body: jsonEncode({
        'text': text,
        'recipientId': recipientId,
        'senderId': senderId, // ✅ تم إضافة هذا السطر الضروري
      }),
    );
  }

  // ✅ تم إصلاح هذه الدالة: إضافة قائمة المشاركين
  static Future<String> startChat(String propertyId, String ownerId) async {
    final headers = await _getHeaders();
    final prefs = await SharedPreferences.getInstance();
    final myId = prefs.getString('user_id');

    if (myId == null) throw Exception('User not logged in');

    final response = await http.post(
      Uri.parse('$baseUrl/chats'),
      headers: headers,
      body: jsonEncode({
        'propertyId': propertyId,
        'ownerId': ownerId,
        'participants': [myId, ownerId], // ✅ إضافة هامة جداً
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['chatId'];
    }
    throw Exception('Failed to start chat: ${response.body}');
  }

  static Future<Map<String, dynamic>?> fetchChatInfo(String chatId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/chats/$chatId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      debugPrint('Error fetching chat info ($chatId): ${response.body}');
    } catch (e) {
      debugPrint('Exception fetching chat info ($chatId): $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // ⭐ التقييمات والمراجعات (Ratings & Reviews)
  // ---------------------------------------------------------------------------

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
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
    }
    return [];
  }

  // ✅ تم إصلاح هذه الدالة: إضافة معرف المُقيّم
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
        'reviewerId': myId, // ✅ إرسال المعرف ليظهر التقييم باسمك
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to submit rating');
    }
  }

  // ---------------------------------------------------------------------------
  // 🤝 الصفقات (Deals)
  // ---------------------------------------------------------------------------

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
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching deals: $e');
    }
    return [];
  }

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

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to submit deal request');
    }
  }

  // ---------------------------------------------------------------------------
  // ❤️ المفضلة (Favorites)
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> fetchFavorites(
    String userId,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/favorites'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
    }
    return [];
  }

  static Future<void> toggleFavorite(String propertyId) async {
    final headers = await _getHeaders();
    await http.post(
      Uri.parse('$baseUrl/properties/$propertyId/favorite'),
      headers: headers,
    );
  }

  // ---------------------------------------------------------------------------
  // 🛡️ لوحة الأدمن (Admin Dashboard)
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchAdminStats() async {
    try {
      print('🌐 [API] جلب الإحصائيات من: $baseUrl/admin/stats');
      print('🌐 [API] Fetching stats from: $baseUrl/admin/stats');
      final headers = await _getHeaders();
      print('🔑 [API] Headers prepared for stats request');

      final response = await http.get(
        Uri.parse('$baseUrl/admin/stats'),
        headers: headers,
      );

      print('📥 [API] Stats response status: ${response.statusCode}');
      print('📥 [API] Stats response body: ${response.body}');

      if (response.statusCode == 200) {
        final stats = jsonDecode(response.body);
        print('✅ [API] Stats fetched successfully: $stats');
        return stats;
      } else {
        print('❌ [API] Stats error - Status: ${response.statusCode}');
        print('❌ [API] Stats error - Body: ${response.body}');
      }
    } catch (e) {
      print('❌ [API] Stats exception: $e');
    }
    print('⚠️ [API] Returning default empty stats');
    return {'users': 0, 'properties': 0, 'chats': 0};
  }

  static Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    try {
      debugPrint('🌐 [API] Fetching all users from: $baseUrl/admin/users');
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users'),
        headers: headers,
      );
      debugPrint('📡 [API] Users response status: ${response.statusCode}');
      debugPrint('📦 [API] Users response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ [API] Successfully fetched ${data.length} users');
        return List<Map<String, dynamic>>.from(data);
      } else {
        debugPrint('❌ [API] Failed to fetch users: ${response.statusCode}');
        debugPrint('📄 [API] Error body: ${response.body}');
      }
    } catch (e) {
      debugPrint('💥 [API] Exception while fetching users: $e');
    }
    return [];
  }

  static Future<void> toggleUserBan(String userId, bool ban) async {
    final headers = await _getHeaders();
    await http.post(
      Uri.parse('$baseUrl/admin/users/$userId/ban'),
      headers: headers,
      body: jsonEncode({'isBanned': ban}),
    );
  }

  static Future<void> toggleUserAdmin(String userId, bool makeAdmin) async {
    debugPrint(
      '🔧 [API] Toggling admin status for user: $userId to $makeAdmin',
    );
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/admin'),
        headers: headers,
        body: jsonEncode({'isAdmin': makeAdmin}),
      );

      debugPrint('📥 [API] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ [API] Admin status updated successfully');
      } else {
        debugPrint('❌ [API] Failed to update admin status: ${response.body}');
        throw Exception('فشل تحديث صلاحيات المدير');
      }
    } catch (e) {
      debugPrint('💥 [API] Exception while toggling admin: $e');
      rethrow;
    }
  }

  static Future<void> toggleUserSuperAdmin(
    String userId,
    bool makeSuperAdmin,
  ) async {
    debugPrint(
      '👑 [API] Toggling super admin status for user: $userId to $makeSuperAdmin',
    );
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/super-admin'),
        headers: headers,
        body: jsonEncode({'isSuperAdmin': makeSuperAdmin}),
      );

      debugPrint('📥 [API] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ [API] Super Admin status updated successfully');
      } else {
        debugPrint(
          '❌ [API] Failed to update super admin status: ${response.body}',
        );
        throw Exception('فشل تحديث صلاحيات المدير العام');
      }
    } catch (e) {
      debugPrint('💥 [API] Exception while toggling super admin: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllChats() async {
    try {
      debugPrint('📥 [API] Fetching all chats with details...');
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/chats'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final chats = List<Map<String, dynamic>>.from(
          jsonDecode(response.body),
        );
        debugPrint('✅ [API] Fetched ${chats.length} chats with details');
        return chats;
      }
      debugPrint('❌ [API] Failed to fetch chats: ${response.statusCode}');
    } catch (e) {
      debugPrint('💥 [API] Exception while fetching chats: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchAdminChatMessages(
    String chatId,
  ) async {
    try {
      debugPrint('📥 [API] Fetching messages for chat: $chatId');
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/chats/$chatId/messages'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ [API] Fetched ${data['totalMessages']} messages');
        return data;
      }
      debugPrint('❌ [API] Failed to fetch messages: ${response.statusCode}');
    } catch (e) {
      debugPrint('💥 [API] Exception while fetching messages: $e');
    }
    return null;
  }

  static Future<bool> deleteChat(String chatId) async {
    try {
      debugPrint('🗑️ [API] Deleting chat: $chatId');
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/chats/$chatId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        debugPrint('✅ [API] Chat deleted successfully');
        return true;
      }
      debugPrint('❌ [API] Failed to delete chat: ${response.statusCode}');
    } catch (e) {
      debugPrint('💥 [API] Exception while deleting chat: $e');
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> fetchReports() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/reports'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      /* ignore */
    }
    return [];
  }

  static Future<void> submitReport(Map<String, dynamic> reportData) async {
    final headers = await _getHeaders();
    await http.post(
      Uri.parse('$baseUrl/reports'),
      headers: headers,
      body: jsonEncode(reportData),
    );
  }

  static Future<Map<String, dynamic>> fetchAppSettings() async {
    debugPrint('🛠️ [API] جلب إعدادات التطبيق...');
    try {
      // استخدام endpoint عام بدون صلاحيات admin
      final response = await http.get(
        Uri.parse('$baseUrl/admin/settings/public'),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('🛠️ [API] Settings response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final settings = jsonDecode(response.body);
        debugPrint('✅ [API] Settings fetched: $settings');
        return settings;
      } else {
        debugPrint('⚠️ [API] Settings fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [API] Error fetching settings: $e');
    }
    return {};
  }

  static Future<void> updateAppSettings(Map<String, dynamic> settings) async {
    final headers = await _getHeaders();
    debugPrint('🛠️ [API] Updating app settings...');
    debugPrint('🛠️ [API] Payload: ' + settings.toString());
    final response = await http.post(
      Uri.parse('$baseUrl/admin/settings'),
      headers: headers,
      body: jsonEncode(settings),
    );
    debugPrint('📥 [API] Settings response status: ${response.statusCode}');
    debugPrint('📥 [API] Settings response body: ${response.body}');
    if (response.statusCode != 200 && response.statusCode != 204) {
      String message = 'فشل حفظ الإعدادات';
      try {
        final body = jsonDecode(response.body);
        message = (body['error'] ?? body['message'] ?? message).toString();
      } catch (_) {}
      throw Exception(message);
    }
  }
}
