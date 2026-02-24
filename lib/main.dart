import 'dart:convert';
import 'dart:async';
import 'package:aqar_app/screens/ratings_screen.dart';
import 'package:aqar_app/services/notification_service.dart';
import 'package:aqar_app/screens/auth_gate.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/services/websocket_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:aqar_app/config/theme_controller.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:app_links/app_links.dart';
import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/screens/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:aqar_app/providers/user_provider.dart';
import 'package:aqar_app/providers/chat_provider.dart';
import 'package:aqar_app/providers/properties_refresh_provider.dart';
import 'package:aqar_app/screens/chat_messages_screen.dart';

// ✅ استيراد مكتبات معالجة الأخطاء المتقدمة
import 'dart:ui';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    "🟥 [FCM - Background] Notification received: ${message.messageId}",
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // ✅ 1. اصطياد الأخطاء الحرجة قبل تشغيل التطبيق (Zone Guard)
  runZonedGuarded(
    () async {
      final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
      FlutterNativeSplash.preserve(widgetsBinding: binding);

      // ✅ 2. اصطياد أخطاء واجهة المستخدم (Flutter Errors)
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('🚨 [UI Error Caught]: ${details.exceptionAsString()}');
        // يمكنك هنا إرسال الخطأ إلى خدمة مثل Firebase Crashlytics أو Sentry
      };

      // ✅ 3. اصطياد الأخطاء غير المتزامنة (Async Errors) لمنع إغلاق التطبيق فجأة
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('🚨 [Async Error Caught]: $error');
        debugPrint('StackTrace: $stack');
        return true; // إرجاع true يخبر فلاتر أننا قمنا بمعالجة الخطأ ولن ينهار التطبيق
      };

      // ✅ 4. استبدال الشاشة الحمراء المرعبة بشاشة خطأ أنيقة
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return Material(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    'عذراً، حدث خطأ غير متوقع!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'لقد قمنا بتسجيل الخطأ وجاري العمل على حله.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      };

      await ThemeController.initialize();

      debugPrint("🔵 [System] Initializing Firebase...");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("🟢 [System] Firebase Initialized.");

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await NotificationService.initialize();

      final prefs = await SharedPreferences.getInstance();
      final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
      final bool isLoggedIn = await ApiService.isLoggedIn();

      debugPrint(
        '🔐 [Main] seen_onboarding: $seenOnboarding, isLoggedIn: $isLoggedIn',
      );

      FlutterNativeSplash.remove();

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => UserProvider()..loadUserData(),
            ),
            ChangeNotifierProvider(create: (_) => ChatProvider()),
            ChangeNotifierProvider(create: (_) => PropertiesRefreshProvider()),
          ],
          child: AqarApp(
            startScreen: (seenOnboarding || isLoggedIn)
                ? const AuthGate()
                : const OnboardingScreen(),
          ),
        ),
      );
    },
    (error, stackTrace) {
      // ✅ 5. اصطياد أي خطأ يهرب من الطبقات السابقة
      debugPrint('🔥 [Fatal Error Caught by Zone]: $error');
    },
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
  Timer? _onlineStatusTimer; // ✅ Timer للتحديث الدوري

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    ApiService.onTokenExpired = () {
      if (mounted) {
        ApiService.logout().then((_) {
          if (mounted) {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (ctx) => const AuthGate()),
              (route) => false,
            );
            if (navigatorKey.currentContext != null) {
              ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                const SnackBar(
                  content: Text(
                    'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        });
      }
    };

    _initDeepLinks();
    _setupFirebaseMessaging();
    _updateTokenOnStart();
    _setUserOnline(true);
    _checkUserBanStatus();
    _startOnlineStatusTimer(); // ✅ بدء التحديث الدوري
  }

  @override
  void dispose() {
    _onlineStatusTimer?.cancel(); // ✅ إيقاف التحديث الدوري
    WidgetsBinding.instance.removeObserver(this);
    _setUserOnline(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _setUserOnline(true);
      _startOnlineStatusTimer(); // ✅ بدء التحديث عند فتح التطبيق
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).loadUserData();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _onlineStatusTimer?.cancel(); // ✅ إيقاف التحديث عند إغلاق التطبيق
      _setUserOnline(false);
    }
  }

  Future<void> _setUserOnline(bool isOnline) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null) {
        await ApiService.updateOnlineStatus(userId, isOnline);
        debugPrint('🟢 [Online Status] Updated: $isOnline');
      }
    } catch (e) {
      debugPrint('⚠️ [Online Status Error]: $e');
    }
  }

  // ✅ تحديث دوري لحالة lastSeen كل 3 دقائق
  void _startOnlineStatusTimer() {
    _onlineStatusTimer?.cancel(); // إلغاء أي timer سابق

    _onlineStatusTimer = Timer.periodic(
      const Duration(minutes: 3), // تحديث كل 3 دقائق
      (timer) async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getString('user_id');
          if (userId != null) {
            await ApiService.updateOnlineStatus(userId, true);
            debugPrint('🔄 [Online Status] Auto-updated at ${DateTime.now()}');
          }
        } catch (e) {
          debugPrint('⚠️ [Online Status Timer Error]: $e');
        }
      },
    );
  }

  Future<void> _updateTokenOnStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          ApiService.updateFcmToken(userId, token);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [FCM Token Error]: $e');
    }
  }

  Future<void> _checkUserBanStatus() async {
    try {
      final isLoggedIn = await ApiService.isLoggedIn();
      if (!isLoggedIn) return;

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      WebSocketService.connect(userId);
      final remoteUser = await ApiService.fetchUserProfile(userId);

      if (remoteUser != null) {
        await prefs.setString('user_data', jsonEncode(remoteUser));
      }

      if (remoteUser != null && remoteUser['isBanned'] == true) {
        await ApiService.logout();

        if (mounted) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (ctx) => const AuthGate()),
            (route) => false,
          );

          try {
            if (navigatorKey.currentContext != null && mounted) {
              ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                const SnackBar(
                  content: Text('تم حظر حسابك من قبل الإدارة'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
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
    try {
      _appLinks = AppLinks();
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleLink(initialUri);
      }
      _appLinks.uriLinkStream.listen(
        (Uri? uri) {
          if (uri != null) {
            _handleLink(uri);
          }
        },
        onError: (err) {
          debugPrint('⚠️ [DeepLink Error]: $err');
        },
      );
    } catch (e) {
      debugPrint('⚠️ [Init DeepLink Error]: $e');
    }
  }

  void _setupFirebaseMessaging() {
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null &&
            navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text(message.notification!.title ?? "إشعار جديد"),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
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
    } catch (e) {
      debugPrint('⚠️ [Firebase Messaging Setup Error]: $e');
    }
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    try {
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
              builder: (context) =>
                  PropertyDetailsScreen(propertyId: propertyId),
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('⚠️ [Handle Notification Error]: $e');
    }
  }

  void _handleLink(Uri uri) {
    try {
      debugPrint('🔗 [Deep Link] Received: ${uri.toString()}');
      String? propertyId;

      // دعم كلا الصيغتين: /property/ و /properties/
      if (uri.pathSegments.contains('property')) {
        final index = uri.pathSegments.indexOf('property');
        if (index + 1 < uri.pathSegments.length) {
          propertyId = uri.pathSegments[index + 1];
        }
      } else if (uri.pathSegments.contains('properties')) {
        final index = uri.pathSegments.indexOf('properties');
        if (index + 1 < uri.pathSegments.length) {
          propertyId = uri.pathSegments[index + 1];
        }
      } else if (uri.pathSegments.isNotEmpty) {
        // كاحتياط: خذ آخر جزء من المسار
        propertyId = uri.pathSegments.last;
      }

      if (propertyId != null && propertyId.isNotEmpty) {
        debugPrint('✅ [Deep Link] Opening property: $propertyId');
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (ctx) => PropertyDetailsScreen(propertyId: propertyId!),
            ),
          );
        });
      } else {
        debugPrint('⚠️ [Deep Link] No property ID found in URL');
      }
    } catch (e) {
      debugPrint('⚠️ [Handle Link Error]: $e');
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
              title: 'عقار بلس',
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
