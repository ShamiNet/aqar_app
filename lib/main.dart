// main.dart

import 'package:aqar_app/features/auth/screens/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AqarApp());
}

class AqarApp extends StatelessWidget {
  const AqarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تطبيق عقار',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.teal,
          brightness: Brightness.light,
        ).copyWith(secondary: Colors.amber),
        scaffoldBackgroundColor: Colors.grey[100],
        fontFamily: 'Cairo',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
        ),
      ),
      home: const AuthGate(),
    );
  }
}
