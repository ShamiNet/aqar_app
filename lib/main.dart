// main.dart

import 'package:aqar_app/screens/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:aqar_app/config/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
              title: 'تطبيق عقار',
              themeMode: mode,
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
