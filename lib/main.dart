// main.dart

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:aqar_app/screens/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:aqar_app/config/theme_controller.dart';
// --- استيراد مكتبات التعريب ---
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/localization/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // تفعيل AppCheck (تأكد من أن المفتاح صحيح في Console)
  await FirebaseAppCheck.instance.activate(
    // استخدم debugProvider أثناء التطوير لتجنب المشاكل في المحاكي
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
    // عند الرفع للإنتاج غيرها إلى: AndroidProvider.playIntegrity
  );

  runApp(const AqarApp());
}

class AqarApp extends StatelessWidget {
  const AqarApp({super.key});

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
              debugShowCheckedModeBanner: false,
              title: 'عقار بلص',
              themeMode: mode,

              // --- إعدادات اللغة العربية ---
              locale: const Locale('ar'), // إجبار التطبيق على البدء بالعربية
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                FormBuilderLocalizations
                    .delegate, // تعريب رسائل التحقق في النماذج
              ],

              // ---------------------------
              theme: FlexThemeData.light(
                useMaterial3: true,
                colorScheme: lightScheme,
                textTheme:
                    GoogleFonts.cairoTextTheme(), // خط القاهرة الممتاز للعربية
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
