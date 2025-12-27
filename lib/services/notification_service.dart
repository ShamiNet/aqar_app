import 'package:aqar_app/main.dart';
import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:aqar_app/services/api_service.dart'; // ✅ استخدام السيرفر
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    debugPrint('🔔 [NotificationService] Initializing...');

    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/notification_icon');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _navigateToChat(response.payload!);
        }
      },
    );

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 [NotificationService] Notification clicked (Background).');
      _handleMessage(message);
    });

    final RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🔔 [NotificationService] App launched from notification.');
      _handleMessage(initialMessage);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });
  }

  static void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'chat') {
      final chatId = message.data['chatId'];
      if (chatId != null) {
        _navigateToChat(chatId);
      }
    }
  }

  static Future<void> _navigateToChat(String chatId) async {
    debugPrint('🚀 [NotificationService] Navigating to chat: $chatId');
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('user_id');
    if (currentUserId == null) {
      debugPrint('❌ [NotificationService] No user_id in prefs.');
      return;
    }

    try {
      // ✅ التغيير هنا: استخدام API بدلاً من Firestore
      final chatData = await ApiService.fetchChatInfo(chatId);

      if (chatData == null) {
        debugPrint('❌ [NotificationService] Chat info not found on server.');
        return;
      }

      final Map<String, dynamic> names = chatData['participantNames'] ?? {};
      String recipientId = '';
      String recipientName = 'مستخدم';

      names.forEach((key, value) {
        if (key != currentUserId) {
          recipientId = key;
          recipientName = value.toString();
        }
      });

      if (recipientId.isEmpty) return;

      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (ctx) => ChatMessagesScreen(
              chatId: chatId,
              recipientId: recipientId,
              recipientName: recipientName,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [NotificationService] Error navigating to chat: $e');
    }
  }

  // تم نقل saveTokenToFirestore إلى ApiService واستدعاؤها في TabsScreen
  // لذلك لا نحتاجها هنا.

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@drawable/notification_icon',
          ),
        ),
        payload: message.data['chatId'],
      );
    }
  }
}
