import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebSocketService {
  // ✅ تم تحديث الرابط ليعمل على الاتصال المشفر (wss) مع الدومين الخاص بك
  // المنفذ 3001 هو المنفذ الذي يعمل عليه سيرفر Node.js
  static const String _serverUrl = 'wss://s313.store';

  static WebSocketChannel? _channel;
  static final List<Function(dynamic)> _listeners = [];
  static Timer? _reconnectTimer;
  static String? _currentUserId; // لتخزين المعرف لإعادة الاتصال
  static bool _skipReconnect =
      false; // تجاهل إعادة الاتصال في حالات القطع المقصود

  // ✅ إضافة متغيرات لإدارة إعادة الاتصال بشكل أفضل
  static int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const int _baseReconnectDelay = 3; // ثواني
  static const int _maxReconnectDelay = 60; // ثواني
  static bool _isConnecting = false;

  // 🔌 بدء الاتصال
  static Future<void> connect(String userId) async {
    _currentUserId = userId; // حفظ المعرف

    // إذا كان متصلاً أو في حالة اتصال حالياً، لا تفعل شيئاً
    if (_isConnecting) {
      debugPrint('⏳ [مقابس الويب] محاولة اتصال جارية بالفعل...');
      return;
    }

    if (_channel != null && _channel!.closeCode == null) {
      debugPrint('✅ [مقابس الويب] الاتصال قائم بالفعل');
      return;
    }

    // التحقق من الاتصال بالإنترنت قبل المحاولة
    if (!await _hasInternetConnection()) {
      debugPrint('📡 [مقابس الويب] لا يوجد اتصال بالإنترنت');
      _scheduleReconnect();
      return;
    }

    _isConnecting = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        debugPrint(
          '⚠️ [مقابس الويب] لم يتم العثور على التوكن. تم إيقاف الاتصال.',
        );
        _isConnecting = false;
        return;
      }

      debugPrint(
        '🔌 [مقابس الويب] محاولة الاتصال (#${_reconnectAttempts + 1})...',
      );

      _channel = IOWebSocketChannel.connect(
        Uri.parse('$_serverUrl?userId=$userId&token=$token'),
        pingInterval: const Duration(seconds: 10),
        connectTimeout: const Duration(seconds: 10),
      );

      _channel!.stream.listen(
        (message) {
          // نجح الاتصال - إعادة تعيين العداد
          if (_reconnectAttempts > 0) {
            debugPrint(
              '✅ [مقابس الويب] تم الاتصال بنجاح بعد $_reconnectAttempts محاولة',
            );
            _reconnectAttempts = 0;
          }

          try {
            final data = jsonDecode(message);
            for (var listener in _listeners) {
              listener(data);
            }
          } catch (e) {
            debugPrint('⚠️ [مقابس الويب] خطأ في فك التشفير: $e');
          }
        },
        onError: (error) {
          _isConnecting = false;
          _handleConnectionError(error);

          if (_skipReconnect) {
            _skipReconnect = false;
            return;
          }
          _scheduleReconnect();
        },
        onDone: () {
          _isConnecting = false;
          _channel = null;

          if (_skipReconnect) {
            _skipReconnect = false;
            return;
          }

          debugPrint('❌ [مقابس الويب] تم إغلاق الاتصال');
          _scheduleReconnect();
        },
      );

      _isConnecting = false;
    } catch (e) {
      _isConnecting = false;
      _handleConnectionError(e);
      _scheduleReconnect();
    }
  }

  // 🔍 التحقق من وجود اتصال بالإنترنت
  static Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // 🔴 معالجة أخطاء الاتصال
  static void _handleConnectionError(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('Failed host lookup') ||
        errorString.contains('No address associated with hostname')) {
      debugPrint('💥 [مقابس الويب] خطأ DNS: لا يمكن الوصول للخادم');
    } else if (errorString.contains('Connection timed out')) {
      debugPrint('⏱️ [مقابس الويب] انتهت مهلة الاتصال');
    } else if (errorString.contains('Connection refused')) {
      debugPrint('🚫 [مقابس الويب] تم رفض الاتصال من الخادم');
    } else if (errorString.contains('Network is unreachable')) {
      debugPrint('📡 [مقابس الويب] الشبكة غير متاحة');
    } else {
      debugPrint('💥 [مقابس الويب] خطأ في الاتصال: $error');
    }
  }

  // ✅ الدالة التي يطلبها ApiService عند انتهاء صلاحية الجلسة
  static Future<void> reconnectWithNewToken() async {
    if (_currentUserId != null) {
      debugPrint('🔄 [مقابس الويب] تم تجديد التوكن. جاري إعادة الاتصال...');
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0; // إعادة تعيين العداد عند تجديد التوكن

      // قطع الاتصال القديم بدون تفعيل إعادة الاتصال التلقائي "القديم"
      disconnect(skipAutoReconnect: true);

      // انتظار بسيط لضمان إغلاق القناة السابقة
      await Future.delayed(const Duration(milliseconds: 500));

      // الاتصال مجدداً (سيستخدم التوكن الجديد المخزن في SharedPreferences)
      connect(_currentUserId!);
    }
  }

  // 🔄 جدولة إعادة الاتصال مع Exponential Backoff
  static void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    // التحقق من عدد المحاولات
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
        '⛔ [مقابس الويب] تم الوصول للحد الأقصى من محاولات الاتصال ($_maxReconnectAttempts). سيتم إيقاف المحاولات.',
      );
      // إعادة تعيين العداد بعد 5 دقائق
      _reconnectTimer = Timer(const Duration(minutes: 5), () {
        debugPrint('🔄 [مقابس الويب] إعادة تعيين عداد المحاولات...');
        _reconnectAttempts = 0;
        if (_currentUserId != null) {
          connect(_currentUserId!);
        }
      });
      return;
    }

    // حساب وقت الانتظار باستخدام Exponential Backoff
    final delay = _calculateBackoffDelay();

    debugPrint(
      '🔄 [مقابس الويب] إعادة المحاولة بعد $delay ثانية (محاولة ${_reconnectAttempts + 1}/$_maxReconnectAttempts)...',
    );

    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_currentUserId != null) {
        connect(_currentUserId!);
      }
    });
  }

  // 📊 حساب وقت الانتظار باستخدام Exponential Backoff
  static int _calculateBackoffDelay() {
    // Exponential backoff: delay = base * 2^attempts
    final exponentialDelay = (_baseReconnectDelay * (1 << _reconnectAttempts))
        .toInt();
    // التأكد من عدم تجاوز الحد الأقصى
    return exponentialDelay > _maxReconnectDelay
        ? _maxReconnectDelay
        : exponentialDelay;
  }

  // 🔄 إعادة تعيين حالة الاتصال يدوياً (للاستخدام عند استعادة الاتصال بالإنترنت)
  static void resetAndReconnect() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    if (_currentUserId != null) {
      debugPrint('🔄 [مقابس الويب] إعادة تعيين يدوية - محاولة الاتصال...');
      connect(_currentUserId!);
    }
  }

  // 🎧 إدارة المستمعين (لإرسال الرسائل للشاشات)
  static void addListener(Function(dynamic) callback) {
    if (!_listeners.contains(callback)) _listeners.add(callback);
  }

  static void removeListener(Function(dynamic) callback) {
    _listeners.remove(callback);
  }

  // ❌ قطع الاتصال
  static void disconnect({bool skipAutoReconnect = false}) {
    _skipReconnect = skipAutoReconnect;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0; // إعادة تعيين العداد عند القطع اليدوي
    _isConnecting = false;

    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }

    debugPrint('🔌 [مقابس الويب] تم قطع الاتصال');
  }

  // ℹ️ الحصول على حالة الاتصال
  static bool get isConnected =>
      _channel != null && _channel!.closeCode == null;

  static bool get isConnecting => _isConnecting;

  static int get reconnectAttempts => _reconnectAttempts;
}
