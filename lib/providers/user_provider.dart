import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aqar_app/services/api_service.dart';

class UserProvider with ChangeNotifier {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;

  // ✅ خصائص جاهزة للاستخدام في الواجهة (Getters)
  String get username => _userData?['username'] ?? 'ضيف';
  String get email => _userData?['email'] ?? '';
  String? get profileImage => _userData?['profileImageUrl'];
  bool get isVerified => _userData?['isVerified'] ?? false;

  // ✅ منطق التحقق من الصلاحيات مركزي هنا
  bool get isAdmin {
    if (_userData == null) return false;
    final role = _userData!['role'];
    return (role.toString().toLowerCase() == 'admin' ||
            role == 'مدير' ||
            role.toString().toLowerCase() == 'owner' ||
            role.toString().toLowerCase() == 'super_admin') ||
        (_userData!['isAdmin'] == true) ||
        (_userData!['isSuperAdmin'] == true);
  }

  // 🔄 تحميل البيانات عند بدء التطبيق
  Future<void> loadUserData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // محاولة الجلب من الذاكرة المحلية أولاً (للسرعة)
      final prefs = await SharedPreferences.getInstance();
      final localData = prefs.getString('user_data');
      final userId = prefs.getString('user_id');

      if (localData != null) {
        _userData = jsonDecode(localData);
        _isLoading = false;
        notifyListeners(); // تحديث فوري للواجهة
        debugPrint(
          '✅ [UserProvider] Local data loaded for user: ${_userData?['username']}',
        );
      }

      // ثم التحديث من السيرفر (للدقة)
      if (userId != null) {
        try {
          final remoteData = await ApiService.fetchUserProfile(userId);
          if (remoteData != null) {
            _userData = remoteData;
            // حفظ النسخة الجديدة محلياً
            await prefs.setString('user_data', jsonEncode(remoteData));
            debugPrint(
              '🌐 [UserProvider] Server data loaded for user: ${_userData?['username']}',
            );
          }
        } catch (e) {
          debugPrint('⚠️ [UserProvider] Failed to fetch from server: $e');
          // الاحتفاظ بالبيانات المحلية إذا فشل السيرفر
        }
      }
    } catch (e) {
      debugPrint('❌ [UserProvider] Error loading user data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ تحديث بيانات المستخدم فوراً (للاستخدام بعد تسجيل الدخول)
  Future<void> refreshUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId != null) {
        debugPrint('🔄 [UserProvider] Refreshing user data...');
        final remoteData = await ApiService.fetchUserProfile(userId);
        if (remoteData != null) {
          _userData = remoteData;
          await prefs.setString('user_data', jsonEncode(remoteData));
          debugPrint(
            '✅ [UserProvider] User data refreshed: ${_userData?['username']}',
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ [UserProvider] Error refreshing user data: $e');
    }
  }

  // 🚪 تسجيل الخروج
  Future<void> logout() async {
    await ApiService.logout();
    _userData = null;
    notifyListeners();
  }
}
