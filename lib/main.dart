// main.dart

// استيراد المكتبات اللازمة
import 'package:aqar_app/features/auth/screens/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // هذا الملف تم إنشاؤه تلقائياً بواسطة flutterfire

// الدالة الرئيسية التي يبدأ منها التطبيق
void main() async {
  // التأكد من تهيئة كل شيء قبل تشغيل التطبيق
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase بناءً على المنصة (ويب أو أندرويد)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // تشغيل التطبيق
  runApp(const AqarApp());
}

// الويدجت الجذر (Root Widget) للتطبيق
class AqarApp extends StatelessWidget {
  const AqarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // لإزالة شريط "Debug"
      debugShowCheckedModeBanner: false,

      // عنوان التطبيق
      title: 'تطبيق عقار',

      // تحديد الثيم (Theme) الأساسي للتطبيق
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo', // يمكنك إضافة خط عربي جميل لاحقاً
      ),

      // الصفحة الرئيسية للتطبيق هي بوابة المصادقة
      home: const AuthGate(),
    );
  }
}
