import 'dart:convert';
import 'package:aqar_app/screens/ratings_screen.dart';
import 'package:aqar_app/services/notification_service.dart';
import 'package:aqar_app/screens/auth_gate.dart';
import 'package:aqar_app/services/api_service.dart'; // ✅
import 'package:aqar_app/services/websocket_service.dart';
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
import 'package:aqar_app/screens/onboarding_screen.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart'; // ✅ هذه المكتبة رائعة
import 'package:provider/provider.dart'; // ✅ إضافة
import 'package:aqar_app/providers/user_provider.dart'; // ✅ إضافة
import 'package:aqar_app/screens/chat_messages_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    "🟥 [FCM - Background] Notification received: ${message.messageId}",
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.initialize();

  debugPrint("🔵 [System] Initializing Firebase...");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("🟢 [System] Firebase Initialized.");

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

  runApp(
    // ✅ تغليف التطبيق بـ MultiProvider
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()..loadUserData()),
      ],
      child: AqarApp(
        startScreen: seenOnboarding
            ? const AuthGate()
            : const OnboardingScreen(),
      ),
    ),
  );
}

class AqarApp extends StatefulWidget {
  final Widget startScreen;
  const AqarApp({super.key, required this.startScreen});

  @override
  State<AqarApp> createState() => _AqarAppState();
}

class _AqarAppState extends State<AqarApp> with WidgetsBindingObserver {
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 👇 هذا الجزء هو الأهم لحل مشكلة لوحة التحكم
    ApiService.onTokenExpired = () {
      if (mounted) {
        ApiService.logout().then((_) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (ctx) => const AuthGate()),
            (route) => false,
          );
          ScaffoldMessenger.of(navigatorKey.currentState!.context).showSnackBar(
            const SnackBar(
              content: Text('انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى'),
              backgroundColor: Colors.orange,
            ),
          );
        });
      }
    };
    // 👆 نهاية الجزء المضاف
    _initDeepLinks();
    _setupFirebaseMessaging();
    _updateTokenOnStart(); // ✅ تحديث التوكن عبر السيرفر
    _setUserOnline(true); // ✅ المستخدم الآن متصل
    _checkUserBanStatus(); // ✅ فحص فوري عند فتح التطبيق مرة واحدة فقط
    // ❌ تم إزالة _startBanCheckTimer للحفاظ على الأداء
    // ✅ الفحص الدوري للصيانة أُضيف إلى AuthGate بدلاً من هنا
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserOnline(false); // ✅ المستخدم غادر التطبيق
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _setUserOnline(true); // ✅ رجع للتطبيق
      // هذا سيجلب أحدث البيانات من السيرفر دون الحاجة لتسجيل الخروج
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).loadUserData();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _setUserOnline(false); // ✅ غادر التطبيق مؤقتاً
    }
  }

  Future<void> _setUserOnline(bool isOnline) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null) {
      await ApiService.updateOnlineStatus(userId, isOnline);
    }
  }

  Future<void> _updateTokenOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        ApiService.updateFcmToken(userId, token);
      }
    }
  }

  Future<void> _checkUserBanStatus() async {
    try {
      final isLoggedIn = await ApiService.isLoggedIn();
      debugPrint(
        '🔍 [BanCheck] Checking ban status (Startup)... User logged in: $isLoggedIn',
      );
      if (!isLoggedIn) return;

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;
      if (userId != null) {
        // ✅ بدء اتصال WebSocket
        WebSocketService.connect(userId);
      }

      final remoteUser = await ApiService.fetchUserProfile(userId);

      if (remoteUser != null) {
        await prefs.setString('user_data', jsonEncode(remoteUser));
      }

      if (remoteUser != null && remoteUser['isBanned'] == true) {
        debugPrint(
          '🚫🚫🚫 [BanCheck] USER IS BANNED! Starting logout procedure...',
        );

        await ApiService.logout();

        if (mounted) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (ctx) => const AuthGate()),
            (route) => false,
          );

          try {
            ScaffoldMessenger.of(
              navigatorKey.currentState!.context,
            ).showSnackBar(
              const SnackBar(
                content: Text('تم حظر حسابك من قبل الإدارة'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          } catch (e) {
            debugPrint('⚠️ [BanCheck] Error showing notification: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [BanCheck] Error checking ban status: $e');
    }
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
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        if (navigatorKey.currentState != null) {
          ScaffoldMessenger.of(navigatorKey.currentState!.context).showSnackBar(
            SnackBar(
              content: Text(message.notification!.title ?? "إشعار جديد"),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationData(message.data);
    });

    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        _handleNotificationData(message.data);
      }
    });
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final propertyId = data['propertyId'];
    final String? screenType = data['screen'];

    if (data['type'] == 'new_rating') {
      final myId = FirebaseAuth.instance.currentUser?.uid;
      if (myId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) =>
                RatingsScreen(targetUserId: myId, targetUserName: 'تقييماتي'),
          ),
        );
      }
      return;
    }

    if (screenType == 'chat') {
      final String? chatId = data['chatId'];
      final String? recipientId = data['recipientId'];
      final String? recipientName = data['recipientName'];

      if (chatId != null && recipientId != null) {
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
        return;
      }
    }

    if (propertyId != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => PropertyDetailsScreen(propertyId: propertyId),
          ),
        );
      });
    }
  }

  void _handleLink(Uri uri) {
    String? propertyId;
    if (uri.pathSegments.contains('properties')) {
      final index = uri.pathSegments.indexOf('properties');
      if (index + 1 < uri.pathSegments.length)
        propertyId = uri.pathSegments[index + 1];
    } else if (uri.pathSegments.isNotEmpty) {
      propertyId = uri.pathSegments.last;
    }

    if (propertyId != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (ctx) => PropertyDetailsScreen(propertyId: propertyId!),
          ),
        );
      });
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
                colorScheme: ColorScheme.fromSeed(
                  seedColor: seed,
                  brightness: Brightness.light,
                  primary: seed,
                ),
                useMaterial3: true,
                subThemesData: const FlexSubThemesData(
                  defaultRadius: 12.0,
                  inputDecoratorRadius: 12.0,
                  elevatedButtonRadius: 12.0,
                  outlinedButtonRadius: 12.0,
                  cardElevation: 2.0,
                ),
                textTheme: GoogleFonts.cairoTextTheme(),
              ),
              darkTheme: FlexThemeData.dark(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: seed,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
                subThemesData: const FlexSubThemesData(
                  defaultRadius: 12.0,
                  inputDecoratorRadius: 12.0,
                  elevatedButtonRadius: 12.0,
                  outlinedButtonRadius: 12.0,
                  cardElevation: 2.0,
                  blendOnLevel: 20,
                ),
                textTheme: GoogleFonts.cairoTextTheme(
                  ThemeData.dark().textTheme,
                ),
              ),
              home: widget.startScreen,
            );
          },
        );
      },
    );
  }
}
