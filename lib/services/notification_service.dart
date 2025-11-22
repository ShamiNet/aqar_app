import 'package:aqar_app/main.dart'; // لاستيراد navigatorKey
import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // طلب الأذونات
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // إعدادات الإشعار المحلي
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/notification_icon');

    // هنا نعالج الضغط على الإشعار وهو التطبيق مفتوح (Foreground)
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // معالجة الضغط على الإشعار المحلي
        if (response.payload != null) {
          // الـ payload هنا سيكون chatId
          _navigateToChat(response.payload!);
        }
      },
    );

    // 1. معالجة فتح التطبيق من الخلفية (Background State)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message);
    });

    // 2. معالجة فتح التطبيق وهو مغلق تماماً (Terminated State)
    final RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // 3. الاستماع للرسائل أثناء الاستخدام (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });
  }

  // دالة التوجيه الذكي
  static void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'chat') {
      final chatId = message.data['chatId'];
      if (chatId != null) {
        _navigateToChat(chatId);
      }
    }
  }

  // الدالة التي تقوم بالانتقال الفعلي
  static Future<void> _navigateToChat(String chatId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // 1. جلب بيانات المحادثة لمعرفة اسم ورقم الطرف الآخر
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) return;

      final data = chatDoc.data()!;
      final Map<String, dynamic> names = data['participantNames'] ?? {};

      // تحديد الطرف الآخر
      String recipientId = '';
      String recipientName = 'مستخدم';

      names.forEach((key, value) {
        if (key != currentUser.uid) {
          recipientId = key;
          recipientName = value.toString();
        }
      });

      // إذا لم نجد معرفاً (حالة نادرة)، نستخدم الافتراضي
      if (recipientId.isEmpty) return;

      // 2. الانتقال للشاشة باستخدام المفتاح العام
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
      debugPrint('Error navigating to chat: $e');
    }
  }

  static Future<void> saveTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'fcmToken': newToken},
      );
    });
  }

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
        // نمرر chatId كـ payload لكي نستخدمه عند الضغط
        payload: message.data['chatId'],
      );
    }
  }
}
