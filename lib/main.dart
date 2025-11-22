import 'package:aqar_app/services/notification_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:aqar_app/screens/auth_gate.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:aqar_app/config/theme_controller.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:app_links/app_links.dart';
import 'package:aqar_app/screens/property_details_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.initialize();

  // await FirebaseAppCheck.instance.activate(
  //   androidProvider: AndroidProvider.debug,
  //   appleProvider: AppleProvider.debug,
  // );

  runApp(const AqarApp());
}

class AqarApp extends StatefulWidget {
  const AqarApp({super.key});

  @override
  State<AqarApp> createState() => _AqarAppState();
}

class _AqarAppState extends State<AqarApp> {
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
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
              home: const AuthGate(),
            );
          },
        );
      },
    );
  }
}
