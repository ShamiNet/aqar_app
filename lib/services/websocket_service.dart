import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebSocketService {
  // ✅ تأكد أن هذا الرابط صحيح ويوافق السيرفر الخاص بك
  static const String _serverUrl = 'ws://72.60.80.201:3001';

  static WebSocketChannel? _channel;
  static final List<Function(dynamic)> _listeners = [];
  static Timer? _reconnectTimer;
  static String? _currentUserId; // لتخزين المعرف لإعادة الاتصال
  static bool _skipReconnect =
      false; // تجاهل إعادة الاتصال في حالات القطع المقصود

  // 🔌 بدء الاتصال
  static Future<void> connect(String userId) async {
    _currentUserId = userId; // حفظ المعرف

    // إذا كان متصلاً، لا تفعل شيئاً
    if (_channel != null && _channel!.closeCode == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        debugPrint('⚠️ [WebSocket] No token found. Aborting.');
        return;
      }

      debugPrint('🔌 [WebSocket] Connecting...');

      _channel = IOWebSocketChannel.connect(
        Uri.parse('$_serverUrl?userId=$userId&token=$token'),
        pingInterval: const Duration(seconds: 10), // الحفاظ على الاتصال حياً
      );

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            for (var listener in _listeners) listener(data);
          } catch (e) {
            debugPrint('⚠️ [WebSocket] Decode Error: $e');
          }
        },
        onError: (error) {
          debugPrint('💥 [WebSocket] Error: $error');
          if (_skipReconnect) {
            _skipReconnect = false;
            return;
          }
          _reconnect();
        },
        onDone: () {
          _channel = null;
          if (_skipReconnect) {
            _skipReconnect = false;
            return;
          }
          debugPrint('❌ [WebSocket] Closed. Reconnecting in 3s...');
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('💥 [WebSocket] Connect Failed: $e');
      _reconnect();
    }
  }

  // ✅ الدالة التي يطلبها ApiService (تأكد من وجودها هنا)
  static Future<void> reconnectWithNewToken() async {
    if (_currentUserId != null) {
      debugPrint('🔄 [WebSocket] Token refreshed. Reconnecting socket...');
      _reconnectTimer?.cancel();

      // قطع الاتصال القديم بدون تفعيل إعادة الاتصال التلقائي "القديم"
      disconnect(skipAutoReconnect: true);

      // انتظار بسيط لضمان إغلاق القناة السابقة
      await Future.delayed(const Duration(milliseconds: 500));

      // الاتصال مجدداً (سيستخدم التوكن الجديد المخزن في SharedPreferences)
      connect(_currentUserId!);
    }
  }

  // 🔄 إعادة الاتصال التلقائي
  static void _reconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_currentUserId != null) {
        debugPrint('🔄 [WebSocket] Auto-reconnecting...');
        connect(_currentUserId!);
      }
    });
  }

  // 🎧 إدارة المستمعين
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
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
  }
}
