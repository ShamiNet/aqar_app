import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  // ✅ العنوان الصحيح للسيرفر
  static const String _serverUrl = 'ws://72.60.80.201:3001';

  static WebSocketChannel? _channel;
  // قائمة المستمعين (الشاشات التي تنتظر رسائل)
  static final List<Function(dynamic)> _listeners = [];
  static Timer? _reconnectTimer;

  // 🔌 دالة الاتصال (Static)
  static void connect(String userId) {
    // إذا كان متصلاً بالفعل، لا تفعل شيئاً
    if (_channel != null && _channel!.closeCode == null) return;

    try {
      debugPrint('🔌 [WebSocket] Connecting to $_serverUrl?userId=$userId');

      // إنشاء الاتصال
      _channel = IOWebSocketChannel.connect(
        Uri.parse('$_serverUrl?userId=$userId'),
      );

      // الاستماع للبيانات القادمة
      _channel!.stream.listen(
        (message) {
          debugPrint('📩 [WebSocket] Received: $message');
          try {
            final data = jsonDecode(message);
            // إرسال البيانات لكل الشاشات المشتركة (Observer Pattern)
            for (var listener in _listeners) {
              listener(data);
            }
          } catch (e) {
            debugPrint('⚠️ [WebSocket] Failed to decode message: $e');
          }
        },
        onError: (error) {
          debugPrint('💥 [WebSocket] Error: $error');
          _reconnect(userId);
        },
        onDone: () {
          debugPrint('❌ [WebSocket] Connection closed');
          _channel = null;
          _reconnect(userId);
        },
      );
    } catch (e) {
      debugPrint('💥 [WebSocket] Connection failed: $e');
      _reconnect(userId);
    }
  }

  // 🔄 منطق إعادة الاتصال التلقائي
  static void _reconnect(String userId) {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('🔄 [WebSocket] Reconnecting...');
      connect(userId);
    });
  }

  // ➕ إضافة مستمع (شاشة تريد استقبال الرسائل)
  static void addListener(Function(dynamic) callback) {
    if (!_listeners.contains(callback)) {
      _listeners.add(callback);
    }
  }

  // ➖ إزالة مستمع (عند إغلاق الشاشة)
  static void removeListener(Function(dynamic) callback) {
    _listeners.remove(callback);
  }

  // 🔌 قطع الاتصال
  static void disconnect() {
    _reconnectTimer?.cancel();
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
  }
}
