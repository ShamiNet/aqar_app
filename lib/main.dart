import 'package:aqar_app/screens/ratings_screen.dart';
import 'package:aqar_app/services/notification_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:aqar_app/screens/auth_gate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:aqar_app/config/theme_controller.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:app_links/app_links.dart';
import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/screens/onboarding_screen.dart'; // تأكد من المسار
import 'package:aqar_app/screens/chat_messages_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // طباعة واضحة جداً عند وصول إشعار في الخلفية
  debugPrint("🟥🟥🟥 [FCM - الخلفية] وصل إشعار والتطبيق مغلق! 🟥🟥🟥");
  debugPrint("📦 ID: ${message.messageId}");
  debugPrint("📦 Title: ${message.notification?.title}");
  debugPrint("📦 Body: ${message.notification?.body}");
  debugPrint("📦 Data: ${message.data}");
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.initialize();

  debugPrint("🔵 [System] جاري تهيئة Firebase...");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("🟢 [System] تم تهيئة Firebase بنجاح.");

  // --- إعداد معالجات رسائل FCM ---
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // طلب الصلاحيات وفحصها
  debugPrint("🔵 [FCM] جاري طلب صلاحية الإشعارات...");
  NotificationSettings settings = await FirebaseMessaging.instance
      .requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint('🟢🟢 [FCM] المستخدم وافق على الإشعارات (Authorized)');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    debugPrint('🟡 [FCM] موافقة مؤقتة (Provisional)');
  } else {
    debugPrint('🔴🔴 [FCM] المستخدم رفض الإشعارات أو لم يوافق (Declined)');
  }

  // طباعة التوكن
  _printFCMToken();

  await NotificationService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

  runApp(
    AqarApp(
      startScreen: seenOnboarding ? const AuthGate() : const OnboardingScreen(),
    ),
  );
}

/// دالة لطباعة توكن الجهاز بشكل واضح جداً
void _printFCMToken() async {
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    debugPrint("\n====================================================");
    debugPrint("🔑🔑 [FCM Token] انسخ هذا التوكن للاختبار:");
    debugPrint(fcmToken.toString());
    debugPrint("====================================================\n");
  } catch (e) {
    debugPrint("❌ [FCM Error] فشل جلب التوكن: $e");
  }
}

class AqarApp extends StatefulWidget {
  final Widget startScreen;
  const AqarApp({super.key, required this.startScreen});

  @override
  State<AqarApp> createState() => _AqarAppState();
}

class _AqarAppState extends State<AqarApp> {
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _setupFirebaseMessaging();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    final Uri? initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleLink(initialUri);
    }
    _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleLink(uri);
      }
    });
  }

  void _setupFirebaseMessaging() {
    // 1. عند وصول رسالة والتطبيق مفتوح
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '\n🔔🔔🔔 [FCM - Foreground] وصل إشعار والتطبيق مفتوح! 🔔🔔🔔',
      );
      debugPrint('📝 العنوان: ${message.notification?.title}');
      debugPrint('📝 المحتوى: ${message.notification?.body}');
      debugPrint('📦 البيانات (Data): ${message.data}');

      if (message.notification != null) {
        debugPrint('👀 الإشعار يحتوي على بيانات عرض، المفترض يظهر الآن.');
        // هنا يمكنك إظهار SnackBar للتأكد بصرياً
        if (navigatorKey.currentState != null) {
          ScaffoldMessenger.of(navigatorKey.currentState!.context).showSnackBar(
            SnackBar(
              content: Text(" وصل إشعار: ${message.notification!.title}"),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });

    // 2. عند فتح التطبيق من الإشعار
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🚀 [FCM] المستخدم ضغط على الإشعار وفتح التطبيق!');
      _handleNotificationData(message.data);
    });

    // 3. عند فتح التطبيق وكان مغلقاً تماماً
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint('🚀 [FCM] التطبيق فتح من إشعار (Initial Message)!');
        _handleNotificationData(message.data);
      }
    });
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    debugPrint('➡️ [FCM] معالجة التوجيه. البيانات: $data');
    final propertyId = data['propertyId'];

    final String? screenType = data['screen']; // هل هي 'chat' أم عقار؟

    // داخل _handleNotificationData في main.dart
    if (data['type'] == 'new_rating') {
      // هنا يمكنك توجيه المستخدم لصفحة تقييماته الخاصة ليراها
      // أو لصفحة RatingsScreen مع تمرير معرفه الشخصي
      final myId = FirebaseAuth.instance.currentUser?.uid;
      if (myId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) =>
                RatingsScreen(targetUserId: myId, targetUserName: 'تقييماتي'),
          ),
        );
      }
    }
    // الحالة 1: توجيه للمحادثة
    if (screenType == 'chat') {
      final String? chatId = data['chatId'];
      final String? recipientId = data['recipientId'];
      final String? recipientName = data['recipientName'];

      if (chatId != null && recipientId != null) {
        debugPrint('💬 توجيه لشاشة المحادثة: $chatId');
        // تأخير بسيط لضمان جاهزية السياق
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => ChatMessagesScreen(
                chatId: chatId,
                recipientId: recipientId,
                recipientName: recipientName ?? 'مستخدم',
              ),
            ),
          );
        });
        return; // إنهاء الدالة هنا
      }
    }

    // الحالة 2: توجيه للعقار (الكود القديم)

    if (propertyId != null && propertyId != '0') {
      debugPrint('🏠 توجيه للعقار رقم: $propertyId');
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => PropertyDetailsScreen(propertyId: propertyId),
          ),
        );
      });
    }
    if (propertyId != null) {
      debugPrint('✅ [FCM] التوجيه للعقار رقم: $propertyId');
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => PropertyDetailsScreen(propertyId: propertyId),
          ),
        );
      });
    } else {
      debugPrint('⚠️ [FCM] لا يوجد propertyId في الإشعار.');
    }
  }

  // --- الدالة المعدلة والذكية ---
  void _handleLink(Uri uri) {
    debugPrint('🔗 رابط عميق تم استلامه: $uri');
    debugPrint('Host: ${uri.host}');
    debugPrint('Scheme: ${uri.scheme}');
    debugPrint('Path: ${uri.path}');
    debugPrint('Segments: ${uri.pathSegments}');

    String? propertyId;

    // التحقق من الكلمات المفتاحية (properties أو property)
    if (uri.pathSegments.contains('properties')) {
      final index = uri.pathSegments.indexOf('properties');
      if (index + 1 < uri.pathSegments.length) {
        propertyId = uri.pathSegments[index + 1];
      }
    } else if (uri.pathSegments.contains('property')) {
      final index = uri.pathSegments.indexOf('property');
      if (index + 1 < uri.pathSegments.length) {
        propertyId = uri.pathSegments[index + 1];
      }
    }
    // حالة احتياطية: إذا كان الرابط بسيطاً جداً (مثلاً: aqarapp://ID_MUBASHAR)
    else if (uri.pathSegments.isNotEmpty) {
      // نعتبر آخر جزء في الرابط هو الرقم
      propertyId = uri.pathSegments.last;
    }

    if (propertyId != null && propertyId.isNotEmpty) {
      debugPrint('✅ تم استخراج رقم العقار: $propertyId');
      // إضافة تأخير بسيط لضمان جاهزية التطبيق
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (ctx) => PropertyDetailsScreen(propertyId: propertyId!),
          ),
        );
      });
    } else {
      debugPrint('❌ لم يتم العثور على رقم العقار في الرابط');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: ThemeController.seedColor,
          builder: (context, seed, __) {
            final lightScheme = ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.light,
            );
            final darkScheme = ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.dark,
            );

            return MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'عقار بلص',
              themeMode: mode,
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                FormBuilderLocalizations.delegate,
              ],
              theme: FlexThemeData.light(
                useMaterial3: true,
                colorScheme: lightScheme,
                textTheme: GoogleFonts.cairoTextTheme(),
                visualDensity: VisualDensity.standard,
              ),
              darkTheme: FlexThemeData.dark(
                useMaterial3: true,
                colorScheme: darkScheme,
                textTheme: GoogleFonts.cairoTextTheme(),
                visualDensity: VisualDensity.standard,
              ),
              home: widget.startScreen,
            );
          },
        );
      },
    );
  }
}
